-- ELO COURSE — Récompenses des jalons de courses réelles
-- À appliquer uniquement après validation explicite sur la base cible.
-- Les courses sont comptées depuis site_data.data->'races', source réellement utilisée par le site.
-- Récompenses cumulatives : 1 course +10, 5 courses +20, 10 courses +30.
-- Chaque jalon est crédité une seule fois par compte.

create or replace function public.elocoins_claim_race_milestones()
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
  v_transaction_id bigint;
  v_balance bigint := 0;
  v_code text;
  v_reward integer;
  v_label text;
  v_event_key text;
  v_first boolean := false;
  v_five boolean := false;
  v_ten boolean := false;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentification requise.';
  end if;

  select ra.runner_id
    into v_runner_id
    from public.runner_accounts as ra
   where ra.user_id = v_user_id
     and ra.status = 'approved';

  if v_runner_id is null then
    raise exception 'Un compte coureur validé est nécessaire.';
  end if;

  -- Compter uniquement les courses distinctes avec un classement valide
  -- et un temps renseigné pour la fiche coureur liée au compte.
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
  values (
    v_user_id,
    0,
    'ELO' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  )
  on conflict (user_id) do nothing;

  -- Les jalons sont cumulables, mais chaque clé d'événement est unique.
  for v_code, v_reward, v_label, v_event_key in
    select m.code, m.reward, m.label, m.event_key
      from (values
        (1, 'first_race', 10, 'Première course terminée', 'race_milestone:first_race'),
        (5, 'five_races', 20, '5 courses terminées', 'race_milestone:five_races'),
        (10, 'ten_races', 30, '10 courses terminées', 'race_milestone:ten_races')
      ) as m(threshold, code, reward, label, event_key)
     where v_races_count >= m.threshold
     order by m.threshold
  loop
    v_transaction_id := null;
    insert into public.elocoins_transactions
      (user_id, amount, transaction_type, description, event_key)
    values
      (v_user_id, v_reward, v_code, v_label, v_event_key)
    on conflict (user_id, event_key) do nothing
    returning id into v_transaction_id;

    if v_transaction_id is not null then
      update public.elocoins_wallets as w
         set balance = w.balance + v_reward,
             updated_at = now()
       where w.user_id = v_user_id;

      if v_code = 'first_race' then v_first := true;
      elsif v_code = 'five_races' then v_five := true;
      elsif v_code = 'ten_races' then v_ten := true;
      end if;
    end if;
  end loop;

  select w.balance into v_balance
    from public.elocoins_wallets as w
   where w.user_id = v_user_id;

  return query select v_races_count, v_first, v_five, v_ten, coalesce(v_balance, 0);
end;
$function$;

revoke all on function public.elocoins_claim_race_milestones() from public, anon, authenticated;
grant execute on function public.elocoins_claim_race_milestones() to authenticated;
