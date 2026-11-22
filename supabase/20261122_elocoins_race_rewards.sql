-- ELO COURSE — Attribution idempotente des ELOCOINS liés aux résultats de course.
-- À appliquer uniquement après validation explicite. Cette migration inclut un rattrapage historique.

CREATE OR REPLACE FUNCTION public.elocoins_credit_race_rewards_for_runner(
  p_user_id uuid,
  p_runner_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
DECLARE
  v_race record;
  v_amount integer;
  v_transaction_id bigint;
BEGIN
  IF p_user_id IS NULL OR p_runner_id IS NULL OR btrim(p_runner_id) = '' THEN
    RETURN;
  END IF;

  INSERT INTO public.elocoins_wallets (user_id, balance, referral_code)
  VALUES (
    p_user_id,
    0,
    'ELO' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  )
  ON CONFLICT (user_id) DO NOTHING;

  FOR v_race IN
    WITH raw_results AS (
      SELECT
        c->>'id' AS race_id,
        COALESCE(NULLIF(c->>'name', ''), 'Course ELO COURSE') AS race_name,
        r->>'id' AS runner_id,
        CASE
          WHEN COALESCE(r->>'rk', '') ~ '^[0-9]+$' THEN (r->>'rk')::integer
          ELSE NULL
        END AS imported_rank,
        CASE
          WHEN COALESCE(r->>'time', '') ~ '^[0-9]+([.][0-9]+)?$'
            THEN (r->>'time')::numeric
          WHEN COALESCE(r->>'time', '') ~ '^[0-9]+:[0-5][0-9]$'
            THEN split_part(r->>'time', ':', 1)::numeric * 60
               + split_part(r->>'time', ':', 2)::numeric
          WHEN COALESCE(r->>'time', '') ~ '^[0-9]+:[0-5][0-9]:[0-5][0-9]$'
            THEN split_part(r->>'time', ':', 1)::numeric * 3600
               + split_part(r->>'time', ':', 2)::numeric * 60
               + split_part(r->>'time', ':', 3)::numeric
          ELSE NULL
        END AS time_seconds
      FROM public.site_data AS sd
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE
          WHEN jsonb_typeof(sd.data->'races') = 'array' THEN sd.data->'races'
          ELSE '[]'::jsonb
        END
      ) AS c
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE
          WHEN jsonb_typeof(c->'results') = 'array' THEN c->'results'
          ELSE '[]'::jsonb
        END
      ) AS r
      WHERE sd.id = 1
        AND c->>'id' IS NOT NULL
        AND r->>'id' IS NOT NULL
        AND lower(COALESCE(r->>'pending', 'false')) <> 'true'
    ),
    ranked_results AS (
      SELECT
        rr.*,
        rank() OVER (
          PARTITION BY rr.race_id
          ORDER BY rr.time_seconds NULLS LAST
        ) AS computed_rank
      FROM raw_results AS rr
      WHERE rr.imported_rank > 0 OR rr.time_seconds > 0
    ),
    runner_races AS (
      SELECT DISTINCT ON (race_id)
        race_id,
        race_name,
        COALESCE(NULLIF(imported_rank, 0), computed_rank)::integer AS final_rank
      FROM ranked_results
      WHERE runner_id = p_runner_id
      ORDER BY
        race_id,
        CASE WHEN imported_rank IS NOT NULL AND imported_rank > 0 THEN 0 ELSE 1 END,
        COALESCE(NULLIF(imported_rank, 0), computed_rank),
        time_seconds NULLS LAST
    )
    SELECT race_id, race_name, final_rank
    FROM runner_races
    ORDER BY race_id
  LOOP
    v_amount := 10
      + CASE
          WHEN v_race.final_rank BETWEEN 1 AND 100 THEN 101 - v_race.final_rank
          ELSE 0
        END;

    v_transaction_id := NULL;

    INSERT INTO public.elocoins_transactions
      (user_id, amount, transaction_type, description, event_key)
    VALUES
      (
        p_user_id,
        v_amount,
        'race_result',
        'Résultat validé : ' || v_race.race_name
          || ' · ' || CASE
               WHEN v_race.final_rank BETWEEN 1 AND 100
                 THEN '10 ELOCOINS + bonus Top 100 (' || v_race.final_rank || 'e place)'
               ELSE '10 ELOCOINS'
             END,
        'race:' || v_race.race_id
      )
    ON CONFLICT (user_id, event_key) DO NOTHING
    RETURNING id INTO v_transaction_id;

    IF v_transaction_id IS NOT NULL THEN
      UPDATE public.elocoins_wallets
      SET balance = balance + v_amount,
          updated_at = now()
      WHERE user_id = p_user_id;
    END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elocoins_credit_all_race_rewards()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
DECLARE
  v_account record;
BEGIN
  FOR v_account IN
    SELECT user_id, runner_id
    FROM public.runner_accounts
    WHERE status = 'approved'
  LOOP
    PERFORM public.elocoins_credit_race_rewards_for_runner(
      v_account.user_id,
      v_account.runner_id
    );
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elocoins_sync_race_rewards_on_account_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
BEGIN
  IF NEW.status = 'approved' THEN
    PERFORM public.elocoins_credit_race_rewards_for_runner(
      NEW.user_id,
      NEW.runner_id
    );
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elocoins_sync_race_rewards_on_site_data_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.data->'races' IS NOT DISTINCT FROM OLD.data->'races' THEN
    RETURN NEW;
  END IF;

  PERFORM public.elocoins_credit_all_race_rewards();
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS elocoins_race_rewards_after_account_approval
  ON public.runner_accounts;
CREATE TRIGGER elocoins_race_rewards_after_account_approval
AFTER INSERT OR UPDATE OF status, runner_id
ON public.runner_accounts
FOR EACH ROW
EXECUTE FUNCTION public.elocoins_sync_race_rewards_on_account_change();

DROP TRIGGER IF EXISTS elocoins_race_rewards_after_site_data_change
  ON public.site_data;
CREATE TRIGGER elocoins_race_rewards_after_site_data_change
AFTER INSERT OR UPDATE OF data
ON public.site_data
FOR EACH ROW
EXECUTE FUNCTION public.elocoins_sync_race_rewards_on_site_data_change();

REVOKE ALL ON FUNCTION public.elocoins_credit_race_rewards_for_runner(uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.elocoins_credit_all_race_rewards()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.elocoins_sync_race_rewards_on_account_change()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.elocoins_sync_race_rewards_on_site_data_change()
  FROM PUBLIC, anon, authenticated;

-- Backfill unique rewards for all currently approved runner accounts.
SELECT public.elocoins_credit_all_race_rewards();
