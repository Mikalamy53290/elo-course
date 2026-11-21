-- ELO COURSE — sécurisation et activation du vrai parrainage
-- À appliquer uniquement après validation explicite de Mickaël.
-- Aucun bonus de bienvenue : les 50 coins du filleul et 20 du parrain
-- sont versés uniquement lorsqu'un compte avec un parrain est approuvé.

create schema if not exists elo_private;
revoke all on schema elo_private from public, anon, authenticated;

-- Les triggers existants conservent leur liaison aux fonctions lors du
-- déplacement de celles-ci hors du schéma public exposé par l'API.
alter function public.elocoins_capture_referral_on_account_insert()
  set schema elo_private;
alter function public.elocoins_reward_referrer_on_approval()
  set schema elo_private;

-- Le bonus de bienvenue général de 50 coins ne correspond pas à la règle
-- validée : il est retiré. Les comptes sans parrain ne reçoivent rien.
drop trigger if exists elocoins_welcome_after_insert on public.runner_accounts;
drop trigger if exists elocoins_welcome_after_approval on public.runner_accounts;
drop function if exists public.elocoins_grant_welcome_on_approval();

create or replace function elo_private.elocoins_capture_referral_on_account_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_code text;
  v_referrer uuid;
begin
  if new.user_id = '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid then
    return new;
  end if;

  select upper(trim(coalesce(u.raw_user_meta_data->>'referral_code', '')))
    into v_code
    from auth.users as u
   where u.id = new.user_id;

  if v_code is null or v_code = '' or v_code !~ '^[A-Z0-9]{3,32}$' then
    return new;
  end if;

  -- Un code n'est valide que s'il appartient au portefeuille d'un coureur
  -- déjà approuvé. Le compte administrateur ne peut ni parrainer ni être filleul.
  select w.user_id
    into v_referrer
    from public.elocoins_wallets as w
    join public.runner_accounts as ra on ra.user_id = w.user_id
   where upper(w.referral_code) = v_code
     and ra.status = 'approved'
     and w.user_id <> new.user_id
     and w.user_id <> '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid
   limit 1;

  if v_referrer is null then
    return new;
  end if;

  insert into public.elocoins_referrals
    (referrer_user_id, referred_user_id, referral_code, status)
  values
    (v_referrer, new.user_id, v_code, 'pending')
  on conflict (referred_user_id) do nothing;

  return new;
end;
$function$;

create or replace function elo_private.elocoins_reward_referrer_on_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_referral public.elocoins_referrals%rowtype;
  v_transaction_id bigint;
begin
  if new.user_id = '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid
     or new.status <> 'approved' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'approved' then
    return new;
  end if;

  update public.elocoins_referrals
     set status = 'validated',
         rewarded_at = coalesce(rewarded_at, now())
   where referred_user_id = new.user_id
     and status = 'pending'
     and referrer_user_id <> '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid
  returning * into v_referral;

  if not found then
    return new;
  end if;

  -- Créer les deux portefeuilles si nécessaire, avec un code de partage unique.
  insert into public.elocoins_wallets (user_id, balance, referral_code)
  values (
    v_referral.referred_user_id,
    0,
    'ELO' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  )
  on conflict (user_id) do nothing;

  insert into public.elocoins_wallets (user_id, balance, referral_code)
  values (
    v_referral.referrer_user_id,
    0,
    'ELO' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  )
  on conflict (user_id) do nothing;

  -- 50 coins pour le filleul : une seule attribution grâce à event_key unique.
  insert into public.elocoins_transactions
    (user_id, amount, transaction_type, description, event_key)
  values (
    v_referral.referred_user_id,
    50,
    'referral',
    'Bonus de parrainage — bienvenue du filleul',
    'referral:referred:' || v_referral.referred_user_id::text
  )
  on conflict (user_id, event_key) do nothing
  returning id into v_transaction_id;

  if v_transaction_id is not null then
    update public.elocoins_wallets
       set balance = balance + 50,
           updated_at = now()
     where user_id = v_referral.referred_user_id;
  end if;

  -- 20 coins pour le parrain : autant de filleuls que souhaité.
  v_transaction_id := null;
  insert into public.elocoins_transactions
    (user_id, amount, transaction_type, description, event_key)
  values (
    v_referral.referrer_user_id,
    20,
    'referral',
    'Bonus de parrainage — validation d’un filleul',
    'referral:referrer:' || v_referral.referred_user_id::text
  )
  on conflict (user_id, event_key) do nothing
  returning id into v_transaction_id;

  if v_transaction_id is not null then
    update public.elocoins_wallets
       set balance = balance + 20,
           updated_at = now()
     where user_id = v_referral.referrer_user_id;
  end if;

  return new;
end;
$function$;

-- Les fonctions SECURITY DEFINER restent internes, non appelables via l'API.
revoke all on function elo_private.elocoins_capture_referral_on_account_insert()
  from public, anon, authenticated;
revoke all on function elo_private.elocoins_reward_referrer_on_approval()
  from public, anon, authenticated;

-- Les triggers en place pointent sur les mêmes OID après ALTER FUNCTION SET SCHEMA.
-- Ils continuent donc à capturer le code à la création de la demande puis à
-- distribuer les deux récompenses uniquement lors du passage pending -> approved.
