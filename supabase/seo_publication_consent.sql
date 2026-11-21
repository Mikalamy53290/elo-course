-- ELO COURSE — publication SEO des profils coureurs
-- À exécuter dans Supabase SQL Editor avant d'activer l'indexation des profils.
-- Seuls les comptes approuvés ayant explicitement accepté la publication sont retournés.

alter table public.runner_signup_private
  add column if not exists publication_consent boolean;

create or replace function public.elo_set_publication_consent(p_publication_consent boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentification requise';
  end if;

  update auth.users
     set raw_user_meta_data = jsonb_set(
       coalesce(raw_user_meta_data, '{}'::jsonb),
       '{publication_consent}',
       to_jsonb(coalesce(p_publication_consent, false)),
       true
     )
   where id = auth.uid();

  update public.runner_signup_private
     set publication_consent = coalesce(p_publication_consent, false)
   where user_id = auth.uid();
end;
$$;

create or replace function public.elo_seo_public_runner_ids()
returns table(runner_id text)
language sql
stable
security definer
set search_path = public, auth
as $$
  select distinct ra.runner_id::text
    from public.runner_accounts ra
    join auth.users u on u.id = ra.user_id
    left join public.runner_signup_private sp on sp.user_id = ra.user_id
   where ra.status = 'approved'
     and coalesce(
       sp.publication_consent,
       case
         when u.raw_user_meta_data->>'publication_consent' = 'true' then true
         else false
       end,
       false
     ) = true
     and ra.runner_id is not null;
$$;

revoke all on function public.elo_set_publication_consent(boolean) from public;
revoke all on function public.elo_seo_public_runner_ids() from public;
grant execute on function public.elo_set_publication_consent(boolean) to authenticated;
grant execute on function public.elo_seo_public_runner_ids() to anon, authenticated;
