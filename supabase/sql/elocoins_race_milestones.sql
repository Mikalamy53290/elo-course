-- ELO COURSE — Récompenses des jalons de courses réelles
-- Courses lues exclusivement dans site_data.data->'races', source du site.
-- Jalons de récompense désactivés : les montants restent à valider.
-- Helper privilégié non exposé à l'API REST; wrapper public SECURITY INVOKER.

create schema if not exists elo_private;
revoke all on schema elo_private from public, anon, authenticated;
grant usage on schema elo_private to authenticated;

create or replace function elo_private.elocoins_claim_race_milestones_impl()
returns table (
  races_count integer,
  first_race_credited boolean,
  five_races_credited boolean,
  ten_races_credited boolean,
  balance bigint
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid;
  v_runner_id text;
  v_races_count integer := 0;
  v_balance bigint := 0;
begin
  v_user_id := auth.uid();
  if v_user_id is null then raise exception 'Authentification requise.'; end if;

  -- Le compte administrateur historique ne reçoit pas de récompenses ELO Coins.
  if v_user_id = '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid then
    return query select 0, false, false, false, 0::bigint;
    return;
  end if;

  select ra.runner_id into v_runner_id
    from public.runner_accounts as ra
   where ra.user_id = v_user_id and ra.status = 'approved';

  if v_runner_id is null then
    raise exception 'Un compte coureur validé est nécessaire.';
  end if;

  select count(distinct race_item.race->>'id')::integer
    into v_races_count
    from public.site_data as sd
    cross join lateral jsonb_array_elements(coalesce(sd.data->'races', '[]'::jsonb)) as race_item(race)
    cross join lateral jsonb_array_elements(coalesce(race_item.race->'results', '[]'::jsonb)) as result_item(result)
   where sd.id = 1
     and result_item.result->>'id' = v_runner_id
     and coalesce(result_item.result->>'rk', '') ~ '^[1-9][0-9]*$'
     and nullif(btrim(result_item.result->>'time'), '') is not null;

  insert into public.elocoins_wallets (user_id, balance, referral_code)
  values (v_user_id, 0,
    'ELO' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)))
  on conflict (user_id) do nothing;

  -- Les montants des jalons de courses ne sont pas encore validés.
  -- Cette RPC calcule uniquement le nombre de courses terminées et ne crédite
  -- aucun ELO Coin tant que Mickaël n'a pas confirmé les récompenses.

  select w.balance into v_balance
    from public.elocoins_wallets as w where w.user_id = v_user_id;

  return query select v_races_count, false, false, false, coalesce(v_balance, 0);
end;
$function$;

revoke all on function elo_private.elocoins_claim_race_milestones_impl() from public, anon, authenticated;
grant execute on function elo_private.elocoins_claim_race_milestones_impl() to authenticated;

create or replace function public.elocoins_claim_race_milestones()
returns table (
  races_count integer,
  first_race_credited boolean,
  five_races_credited boolean,
  ten_races_credited boolean,
  balance bigint
)
language sql
security invoker
set search_path = ''
as $function$
  select * from elo_private.elocoins_claim_race_milestones_impl();
$function$;

revoke all on function public.elocoins_claim_race_milestones() from public, anon, authenticated;
grant execute on function public.elocoins_claim_race_milestones() to authenticated;
