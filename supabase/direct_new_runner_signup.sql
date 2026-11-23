-- Inscription directe d'un coureur sans fiche préexistante.
-- Déjà appliqué au projet Supabase ELO COURSE.
drop function if exists public.elo_create_my_runner_profile(text,text,date);
create function public.elo_create_my_runner_profile(
  p_name text, p_sex text, p_date_of_birth date
) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := regexp_replace(trim(coalesce(p_name,'')), '\s+', ' ', 'g');
  v_age integer;
  v_cat text;
  v_id text := replace(gen_random_uuid()::text,'-','');
  v_existing text;
begin
  if v_uid is null then raise exception 'Connexion requise.'; end if;
  if length(v_name) < 4 or array_length(string_to_array(v_name,' '),1) < 2 then raise exception 'Indique ton nom et ton prénom.'; end if;
  if p_sex not in ('H','F') then raise exception 'Sexe invalide.'; end if;
  if p_date_of_birth is null or p_date_of_birth > current_date then raise exception 'Date de naissance invalide.'; end if;
  select runner_id into v_existing from public.runner_accounts where user_id=v_uid;
  if v_existing is not null then return v_existing; end if;
  v_age := date_part('year', age(current_date,p_date_of_birth))::integer;
  if v_age >= 85 then v_cat := 'M10';
  elsif v_age >= 35 then v_cat := 'M' || least(10,floor((v_age-35)/5.0)::integer)::text;
  elsif v_age >= 23 then v_cat := 'SE';
  elsif v_age >= 20 then v_cat := 'ES';
  elsif v_age >= 18 then v_cat := 'JU';
  else v_cat := 'CA'; end if;
  update public.site_data
  set data = jsonb_set(coalesce(data,'{}'::jsonb),'{runners}',
    coalesce(data->'runners','[]'::jsonb) || jsonb_build_array(jsonb_build_object('id',v_id,'name',v_name,'sex',p_sex,'cat',v_cat)),true),
    updated_at=now()
  where id=1;
  if not found then raise exception 'Données ELO COURSE introuvables.'; end if;
  insert into public.runner_accounts(user_id,runner_id,status,approved_at) values(v_uid,v_id,'approved',now());
  return v_id;
end;
$$;
revoke all on function public.elo_create_my_runner_profile(text,text,date) from public, anon;
grant execute on function public.elo_create_my_runner_profile(text,text,date) to authenticated;
