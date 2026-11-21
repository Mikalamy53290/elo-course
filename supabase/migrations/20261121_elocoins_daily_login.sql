-- ELO COURSE — récompense quotidienne de connexion
-- À appliquer à Supabase uniquement après validation explicite.
-- Une attribution maximum par compte et par jour civil en France.

create or replace function public.elocoins_claim_daily_login()
returns table (
  current_balance bigint,
  awarded boolean,
  reward_day date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_today date := (now() at time zone 'Europe/Paris')::date;
  v_transaction_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentification requise';
  end if;

  if not exists (
    select 1
      from public.runner_accounts ra
     where ra.user_id = v_user_id
       and ra.status = 'approved'
  ) then
    raise exception 'Compte coureur validé requis';
  end if;

  if not exists (
    select 1
      from public.elocoins_wallets w
     where w.user_id = v_user_id
  ) then
    raise exception 'Portefeuille ELO Coins introuvable';
  end if;

  insert into public.elocoins_transactions
    (user_id, amount, transaction_type, description, event_key)
  values
    (
      v_user_id,
      10,
      'daily_login',
      'Bonus quotidien de connexion',
      'daily_login:' || v_today::text
    )
  on conflict (user_id, event_key) do nothing
  returning id into v_transaction_id;

  if v_transaction_id is not null then
    update public.elocoins_wallets
       set balance = balance + 10,
           updated_at = now()
     where user_id = v_user_id;
  end if;

  return query
    select w.balance, (v_transaction_id is not null), v_today
      from public.elocoins_wallets w
     where w.user_id = v_user_id;
end;
$function$;

revoke all on function public.elocoins_claim_daily_login() from public;
revoke all on function public.elocoins_claim_daily_login() from anon;
grant execute on function public.elocoins_claim_daily_login() to authenticated;
