-- ELO COURSE — défis de course (migration additive)
-- À exécuter dans Supabase SQL Editor avant d'activer les invitations.
-- Ne modifie ni site_data, ni les résultats, ni le calcul ELO.

create table if not exists public.runner_duel_challenges (
  id uuid primary key default gen_random_uuid(),
  challenger_runner_id text not null,
  opponent_runner_id text not null,
  race_id text not null,
  race_name text not null,
  race_date date not null,
  distance text,
  status text not null default 'pending'
    check (status in ('pending','accepted','refused','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint runner_duel_challenges_distinct_runners
    check (challenger_runner_id <> opponent_runner_id)
);

create index if not exists runner_duel_challenges_challenger_created
  on public.runner_duel_challenges (challenger_runner_id, created_at desc);
create index if not exists runner_duel_challenges_opponent_created
  on public.runner_duel_challenges (opponent_runner_id, created_at desc);
create unique index if not exists runner_duel_challenges_one_active_pair_race
  on public.runner_duel_challenges (challenger_runner_id, opponent_runner_id, race_id)
  where status in ('pending','accepted');

alter table public.runner_duel_challenges enable row level security;

drop policy if exists "Participants can read their race challenges" on public.runner_duel_challenges;
create policy "Participants can read their race challenges"
on public.runner_duel_challenges for select to authenticated
using (
  exists (
    select 1 from public.runner_accounts a
    where a.user_id = auth.uid() and a.status = 'approved'
      and a.runner_id in (challenger_runner_id, opponent_runner_id)
  )
);

drop policy if exists "Linked runners can create their own challenges" on public.runner_duel_challenges;
create policy "Linked runners can create their own challenges"
on public.runner_duel_challenges for insert to authenticated
with check (
  status = 'pending'
  and exists (
    select 1 from public.runner_accounts a
    where a.user_id = auth.uid() and a.status = 'approved'
      and a.runner_id = challenger_runner_id
  )
);

revoke update, delete on public.runner_duel_challenges from anon, authenticated;
grant select, insert on public.runner_duel_challenges to authenticated;

create or replace function public.elo_respond_duel_challenge(p_challenge_id uuid, p_response text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_runner_id text;
begin
  if p_response not in ('accepted','refused') then
    raise exception 'Réponse invalide.';
  end if;
  select runner_id into v_runner_id
  from public.runner_accounts
  where user_id = auth.uid() and status = 'approved'
  limit 1;
  if v_runner_id is null then raise exception 'Aucun profil coureur lié à ce compte.'; end if;

  update public.runner_duel_challenges
  set status = p_response, responded_at = now()
  where id = p_challenge_id
    and opponent_runner_id = v_runner_id
    and status = 'pending';
  if not found then raise exception 'Invitation introuvable ou déjà traitée.'; end if;
end;
$$;

create or replace function public.elo_cancel_duel_challenge(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_runner_id text;
begin
  select runner_id into v_runner_id
  from public.runner_accounts
  where user_id = auth.uid() and status = 'approved'
  limit 1;
  if v_runner_id is null then raise exception 'Aucun profil coureur lié à ce compte.'; end if;

  update public.runner_duel_challenges
  set status = 'cancelled', responded_at = now()
  where id = p_challenge_id
    and challenger_runner_id = v_runner_id
    and status = 'pending';
  if not found then raise exception 'Défi introuvable ou déjà traité.'; end if;
end;
$$;

revoke all on function public.elo_respond_duel_challenge(uuid,text) from public;
revoke all on function public.elo_cancel_duel_challenge(uuid) from public;
grant execute on function public.elo_respond_duel_challenge(uuid,text) to authenticated;
grant execute on function public.elo_cancel_duel_challenge(uuid) to authenticated;

-- Notifications dans le centre de notifications existant.
create or replace function public.elo_notify_duel_challenge()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.runner_notifications (recipient_runner_id, actor_runner_id, kind, created_at)
    values (new.opponent_runner_id, new.challenger_runner_id, 'duel_invitation', now());
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status in ('accepted','refused') then
    insert into public.runner_notifications (recipient_runner_id, actor_runner_id, kind, created_at)
    values (new.challenger_runner_id, new.opponent_runner_id,
      case when new.status = 'accepted' then 'duel_accepted' else 'duel_refused' end, now());
  end if;
  return new;
end;
$$;

drop trigger if exists runner_duel_challenges_notify on public.runner_duel_challenges;
create trigger runner_duel_challenges_notify
after insert or update of status on public.runner_duel_challenges
for each row execute function public.elo_notify_duel_challenge();
