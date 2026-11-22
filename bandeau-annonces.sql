-- ELO COURSE — table du bandeau d'annonces
create table if not exists public.site_announcements (
  id integer primary key check (id = 1),
  message text not null default '',
  active boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.site_announcements enable row level security;

drop policy if exists "Annonces visibles publiquement" on public.site_announcements;
create policy "Annonces visibles publiquement"
on public.site_announcements for select
to anon, authenticated
using (true);

drop policy if exists "Administration des annonces" on public.site_announcements;
create policy "Administration des annonces"
on public.site_announcements for all
to authenticated
using (auth.uid() = '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid)
with check (auth.uid() = '26789cc4-2ac3-4129-95c8-2234b1dc748d'::uuid);

grant select on public.site_announcements to anon, authenticated;
grant insert, update, delete on public.site_announcements to authenticated;

insert into public.site_announcements (id, message, active)
values (1, '', false)
on conflict (id) do nothing;
