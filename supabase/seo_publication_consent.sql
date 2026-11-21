-- ELO COURSE — indexation publique avec consentement explicite
-- À appliquer après validation de cette migration, avant l'activation des pages SEO.
-- La table privée runner_signup_private est l'unique source de vérité du consentement.
-- Aucun contrôle d'indexation ne repose sur raw_user_meta_data, modifiable par l'utilisateur.

-- La colonne existe déjà en production ; IF NOT EXISTS rend la migration portable.
alter table public.runner_signup_private
  add column if not exists publication_consent boolean not null default false;

-- Mise à jour des informations privées : les CGU restent obligatoires,
-- mais le consentement à la publication est facultatif et peut être retiré.
create or replace function public.elo_update_my_runner_private_details(
  p_sex text,
  p_date_of_birth date,
  p_runner_id text,
  p_category text,
  p_terms_accepted boolean,
  p_publication_consent boolean
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_uid uuid;
  v_age integer;
  v_category text;
  v_updated integer;
  v_publication_consent boolean;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Tu dois être connecté.';
  end if;

  if p_runner_id is null or btrim(p_runner_id) = '' then
    raise exception 'Fiche coureur manquante.';
  end if;

  if p_sex not in ('H', 'F') then
    raise exception 'Sexe invalide.';
  end if;

  if p_date_of_birth is null or p_date_of_birth > current_date then
    raise exception 'Date de naissance invalide.';
  end if;

  if p_terms_accepted is distinct from true then
    raise exception 'L’accord sur les conditions est obligatoire.';
  end if;

  v_publication_consent := coalesce(p_publication_consent, false);

  if not exists (
    select 1
    from public.runner_accounts ra
    where ra.user_id = v_uid
      and ra.runner_id = p_runner_id
      and ra.status = 'approved'
  ) then
    raise exception 'Ton compte ne possède pas de fiche coureur validée.';
  end if;

  v_age := extract(year from age(current_date, p_date_of_birth))::integer;

  if v_age >= 35 then
    v_category := 'M' || least(10, floor((v_age - 35)::numeric / 5)::integer)::text;
  elsif v_age >= 23 then
    v_category := 'SE';
  elsif v_age >= 20 then
    v_category := 'ES';
  elsif v_age >= 18 then
    v_category := 'JU';
  elsif v_age >= 16 then
    v_category := 'CA';
  else
    v_category := null;
  end if;

  insert into public.runner_signup_private (
    user_id, runner_id, sex, date_of_birth, terms_accepted,
    publication_consent, terms_accepted_at, publication_consent_at, updated_at
  )
  values (
    v_uid, p_runner_id, p_sex, p_date_of_birth, true,
    v_publication_consent, now(),
    case when v_publication_consent then now() else null end,
    now()
  )
  on conflict (user_id) do update set
    runner_id = excluded.runner_id,
    sex = excluded.sex,
    date_of_birth = excluded.date_of_birth,
    terms_accepted = true,
    publication_consent = excluded.publication_consent,
    terms_accepted_at = now(),
    publication_consent_at = excluded.publication_consent_at,
    updated_at = now();

  -- Le sexe et la catégorie restent synchronisés avec le classement public.
  -- La date de naissance n'est jamais copiée dans site_data.
  update public.site_data sd
  set
    data = jsonb_set(
      sd.data,
      '{runners}',
      (
        select coalesce(
          jsonb_agg(
            case
              when elem->>'id' = p_runner_id then
                elem || jsonb_build_object('sex', p_sex)
                || case
                     when v_category is not null
                     then jsonb_build_object('cat', v_category)
                     else '{}'::jsonb
                   end
              else elem
            end
            order by ord
          ),
          '[]'::jsonb
        )
        from jsonb_array_elements(
          coalesce(sd.data->'runners', '[]'::jsonb)
        ) with ordinality as items(elem, ord)
      ),
      true
    ),
    updated_at = now()
  where sd.id = 1
    and exists (
      select 1
      from jsonb_array_elements(
        coalesce(sd.data->'runners', '[]'::jsonb)
      ) as r
      where r->>'id' = p_runner_id
    );

  get diagnostics v_updated = row_count;

  if v_updated = 0 then
    raise exception 'Fiche coureur introuvable dans le classement.';
  end if;

  return jsonb_build_object(
    'success', true,
    'category', v_category,
    'publication_consent', v_publication_consent
  );
end;
$function$;

-- Seuls les comptes approuvés ayant donné leur accord explicite sont indexables.
-- La fonction ne retourne que des identifiants déjà présents dans le classement public.
create or replace function public.elo_seo_public_runner_ids()
returns table(runner_id text)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select distinct ra.runner_id::text
  from public.runner_accounts ra
  join public.runner_signup_private sp on sp.user_id = ra.user_id
  where ra.status = 'approved'
    and sp.publication_consent is true
    and ra.runner_id is not null;
$function$;

-- Le coureur connecté peut enregistrer ses informations privées.
revoke all on function public.elo_update_my_runner_private_details(text, date, text, text, boolean, boolean) from public, anon;
grant execute on function public.elo_update_my_runner_private_details(text, date, text, text, boolean, boolean) to authenticated;

-- Le Worker a besoin de la liste des seuls profils explicitement publiables.
revoke all on function public.elo_seo_public_runner_ids() from public;
grant execute on function public.elo_seo_public_runner_ids() to anon, authenticated;
