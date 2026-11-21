-- ELO COURSE — Récompense quotidienne de connexion ELO Coins
-- Helper privilégié placé dans un schéma non exposé à l'API REST.
-- Le wrapper public est SECURITY INVOKER et n'expose aucune donnée d'un autre compte.
-- À appliquer uniquement après validation explicite, sur la base cible.

create schema if not exists elo_private;
revoke all on schema elo_private from public, anon, authenticated;
grant usage on schema elo_private to authenticated;

create or replace function elo_private.elocoins_claim_daily_login_impl()
returns table (credited boolean, balance bigint, reward_date date)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid;
  v_status text;
  v_reward_date date;
  v_transaction_id bigint;
  v_balance bigint;
  v_credited boolean := false;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentification requise pour réclamer les ELO Coins.';
  end if;

  -- Le compte administrateur historique reste volontairement à zéro.
  if v_user_id = '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid then
    return query select false, 0::bigint, (now() at time zone 'Europe/Paris')::date;
    return;
  end if;

  select ra.status into v_status
    from public.runner_accounts as ra
   where ra.user_id = v_user_id;

  if v_status is distinct from 'approved' then
    raise exception 'Seuls les comptes coureurs validés peuvent recevoir cette récompense.';
  end if;

  v_reward_date := (now() at time zone 'Europe/Paris')::date;

  insert into public.elocoins_wallets (user_id, balance, referral_code)
  values (v_user_id, 0,
    'ELO' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 24)))
  on conflict (user_id) do nothing;

  insert into public.elocoins_transactions
    (user_id, amount, transaction_type, description, event_key)
  values (v_user_id, 10, 'daily_login',
    'Bonus de connexion quotidienne ELO COURSE',
    'daily_login:' || to_char(v_reward_date, 'YYYY-MM-DD'))
  on conflict (user_id, event_key) do nothing
  returning id into v_transaction_id;

  if v_transaction_id is not null then
    update public.elocoins_wallets as w
       set balance = w.balance + 10, updated_at = now()
     where w.user_id = v_user_id
     returning w.balance into v_balance;
    v_credited := true;
  else
    select w.balance into v_balance
      from public.elocoins_wallets as w
     where w.user_id = v_user_id;
  end if;

  return query select v_credited, coalesce(v_balance, 0), v_reward_date;
end;
$function$;

revoke all on function elo_private.elocoins_claim_daily_login_impl() from public, anon, authenticated;
grant execute on function elo_private.elocoins_claim_daily_login_impl() to authenticated;

create or replace function public.elocoins_claim_daily_login()
returns table (credited boolean, balance bigint, reward_date date)
language sql
security invoker
set search_path = ''
as $function$
  select * from elo_private.elocoins_claim_daily_login_impl();
$function$;

revoke all on function public.elocoins_claim_daily_login() from public, anon, authenticated;
grant execute on function public.elocoins_claim_daily_login() to authenticated;
