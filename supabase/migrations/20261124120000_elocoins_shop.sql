-- ELO COURSE — Boutique ELOCOINS
-- Préparée sur une branche de test. À appliquer uniquement après revue.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table if not exists public.elocoins_catalog (
  id text primary key,
  category text not null check (category in ('Cadres','Badges','Objectifs','Bannières')),
  name text not null,
  description text not null,
  price integer not null check (price > 0),
  tag text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.elocoins_catalog enable row level security;
drop policy if exists "Catalogue ELOCOINS public en lecture" on public.elocoins_catalog;
create policy "Catalogue ELOCOINS public en lecture"
  on public.elocoins_catalog for select to anon, authenticated using (active);
grant select on public.elocoins_catalog to anon, authenticated;

insert into public.elocoins_catalog (id,category,name,description,price,tag) values
('frame_depart_72','Cadres','Cadre Départ 72 (Émeraude)','Contour vert émeraude net pour vos profils sarthois.',30,'Sarthe 72'),
('frame_loire_blue','Cadres','Cadre Foulée Ligérienne (Bleu)','Anneau bleu ciel & azur en rotation douce.',50,'Pays de la Loire'),
('frame_podium_gold','Cadres','Cadre Podium Sarthe (Or)','Halo doré pulsant pour mettre en valeur vos chronos.',70,'Podium'),
('frame_trail_cyan','Cadres','Cadre Trail Nocturne (Cyan)','Cercle lumineux cyan & émeraude pour les sorties nature.',85,'Course Nature'),
('frame_chrono_flame','Cadres','Cadre Flamme Chrono (Feu)','Lueur chaleureuse or et orange pour vos records personnels.',105,'Record'),
('frame_sprint_bolt','Cadres','Cadre Éclair Sprint (Électrique)','Rayures bleu électrique & or pour les finisseurs rapides.',120,'Vitesse'),
('frame_royal_crown','Cadres','Cadre Couronne Vainqueur (Royal)','Couronne dorée au sommet du cadre et anneau royal.',145,'Prestige'),
('frame_legend_prism','Cadres','Cadre Légende 72-53-49 (Prisme)','Dégradé prismatique animé réunissant les territoires.',175,'Régional'),
('badge_sarthe_72','Badges','Coureur de la Sarthe (72)','Badge départemental affiché près de votre avatar et de votre nom.',25,'Département 72'),
('badge_mayenne_53','Badges','Foulée de Mayenne (53)','Badge dédié aux courses et boucles mayennaises.',25,'Département 53'),
('badge_maine_loire_49','Badges','Esprit Anjou • Maine-et-Loire (49)','Badge des parcours et sentiers du Maine-et-Loire.',25,'Département 49'),
('badge_bitume_route','Badges','Spécialiste Bitume & Chrono','Pour les amateurs de 5 km, 10 km et semi-marathons sur route.',45,'Route'),
('badge_trail_nature','Badges','Explorateur Trail & Sentiers','Pour les coureurs qui aiment le dénivelé et les chemins.',45,'Trail'),
('badge_peloton_100','Badges','Chouchou du Peloton','Badge honorifique pour les profils appréciés de la communauté.',65,'Communauté'),
('goal_sobre','Objectifs','Encadré Objectif Sobre','Contour discret et lisible pour votre objectif de course.',15,'Objectif'),
('goal_chrono','Objectifs','Encadré Objectif Bleu Chrono','Reflet bleu ELO COURSE idéal pour un objectif de temps ou d’Elo.',35,'Objectif'),
('goal_trail','Objectifs','Encadré Objectif Vert Sentier','Ambiance émeraude pour vos objectifs de distance et trail.',40,'Objectif'),
('goal_or','Objectifs','Encadré Objectif Doré Défi','Finition dorée pour mettre votre grand défi de saison en avant.',60,'Objectif'),
('banner_bleu_elo','Bannières','Bannière Bleu ELO COURSE','Dégradé bleu nuit et azur signature du site.',30,'Bannière'),
('banner_emeraude_72','Bannières','Bannière Émeraude & Azur','Reflets verts et bleus harmonieux sur le haut du profil.',45,'Bannière'),
('banner_or_peloton','Bannières','Bannière Or & Peloton','Éclat doré discret autour de votre grand cadre et objectif.',65,'Bannière')
on conflict (id) do update set
  category=excluded.category,name=excluded.name,description=excluded.description,
  price=excluded.price,tag=excluded.tag;

create table if not exists public.elocoins_owned_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.elocoins_catalog(id),
  purchase_transaction_id bigint not null references public.elocoins_transactions(id),
  purchased_at timestamptz not null default now(),
  primary key (user_id,item_id)
);
alter table public.elocoins_owned_items enable row level security;
drop policy if exists "Lecture de ses objets ELOCOINS" on public.elocoins_owned_items;
create policy "Lecture de ses objets ELOCOINS"
  on public.elocoins_owned_items for select to authenticated
  using ((select auth.uid()) = user_id);
grant select on public.elocoins_owned_items to authenticated;
revoke insert, update, delete on public.elocoins_owned_items from anon, authenticated;

create table if not exists public.elocoins_equipment (
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('Cadres','Badges','Objectifs','Bannières')),
  item_id text not null references public.elocoins_catalog(id),
  updated_at timestamptz not null default now(),
  primary key (user_id,category)
);
alter table public.elocoins_equipment enable row level security;
drop policy if exists "Lecture de son équipement ELOCOINS" on public.elocoins_equipment;
create policy "Lecture de son équipement ELOCOINS"
  on public.elocoins_equipment for select to authenticated
  using ((select auth.uid()) = user_id);
grant select on public.elocoins_equipment to authenticated;
revoke insert, update, delete on public.elocoins_equipment from anon, authenticated;

create or replace function private.elocoins_purchase_item_impl(p_item_id text, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_user uuid := auth.uid();
  v_status text;
  v_price integer;
  v_name text;
  v_category text;
  v_balance bigint;
  v_tx_id bigint;
  v_event_key text;
begin
  if v_user is null then raise exception 'Connexion requise' using errcode='42501'; end if;
  if p_request_id is null or p_item_id is null then raise exception 'Demande d’achat invalide'; end if;

  select status into v_status from public.runner_accounts where user_id=v_user;
  if v_status is distinct from 'approved' then
    raise exception 'Compte coureur non validé' using errcode='42501';
  end if;

  v_event_key := 'shop:' || p_item_id || ':' || p_request_id::text;

  -- Le verrou portefeuille sérialise les achats simultanés d’un même compte.
  select balance into v_balance from public.elocoins_wallets
   where user_id=v_user for update;
  if not found then raise exception 'Portefeuille ELOCOINS introuvable'; end if;

  -- Idempotence : une répétition de la même requête ne débite jamais deux fois.
  select id into v_tx_id from public.elocoins_transactions
   where user_id=v_user and event_key=v_event_key;
  if found then
    select balance into v_balance from public.elocoins_wallets where user_id=v_user;
    return jsonb_build_object('ok',true,'replayed',true,'transaction_id',v_tx_id,'balance',v_balance);
  end if;

  select price,name,category into v_price,v_name,v_category
    from public.elocoins_catalog where id=p_item_id and active=true;
  if not found then raise exception 'Article indisponible'; end if;

  if exists(select 1 from public.elocoins_owned_items where user_id=v_user and item_id=p_item_id) then
    raise exception 'Article déjà acheté';
  end if;
  if v_balance < v_price then raise exception 'Solde ELOCOINS insuffisant'; end if;

  insert into public.elocoins_transactions
    (user_id,amount,transaction_type,description,event_key)
  values
    (v_user,-v_price,'shop_purchase','Achat boutique : ' || v_name,v_event_key)
  returning id into v_tx_id;

  update public.elocoins_wallets
     set balance=balance-v_price,updated_at=now()
   where user_id=v_user
   returning balance into v_balance;

  insert into public.elocoins_owned_items(user_id,item_id,purchase_transaction_id)
  values(v_user,p_item_id,v_tx_id);

  insert into public.elocoins_equipment(user_id,category,item_id,updated_at)
  values(v_user,v_category,p_item_id,now())
  on conflict(user_id,category) do update
    set item_id=excluded.item_id,updated_at=now();

  return jsonb_build_object('ok',true,'replayed',false,'transaction_id',v_tx_id,'balance',v_balance);
end;
$$;
revoke all on function private.elocoins_purchase_item_impl(text,uuid) from public, anon;
grant execute on function private.elocoins_purchase_item_impl(text,uuid) to authenticated;

create or replace function public.elocoins_purchase_item(p_item_id text,p_request_id uuid)
returns jsonb
language sql
security invoker
set search_path = public, private
as $$ select private.elocoins_purchase_item_impl(p_item_id,p_request_id); $$;
revoke all on function public.elocoins_purchase_item(text,uuid) from public, anon;
grant execute on function public.elocoins_purchase_item(text,uuid) to authenticated;

create or replace function private.elocoins_equip_item_impl(p_category text,p_item_id text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_user uuid := auth.uid();
  v_status text;
  v_item_category text;
begin
  if v_user is null then raise exception 'Connexion requise' using errcode='42501'; end if;
  select status into v_status from public.runner_accounts where user_id=v_user;
  if v_status is distinct from 'approved' then
    raise exception 'Compte coureur non validé' using errcode='42501';
  end if;
  if p_category not in ('Cadres','Badges','Objectifs','Bannières') then raise exception 'Catégorie invalide'; end if;

  if p_item_id is null then
    delete from public.elocoins_equipment where user_id=v_user and category=p_category;
    return jsonb_build_object('ok',true,'equipped',false);
  end if;

  select c.category into v_item_category
    from public.elocoins_catalog c
    join public.elocoins_owned_items o on o.item_id=c.id and o.user_id=v_user
   where c.id=p_item_id and c.active=true;
  if v_item_category is distinct from p_category then
    raise exception 'Article non possédé ou catégorie incorrecte' using errcode='42501';
  end if;

  insert into public.elocoins_equipment(user_id,category,item_id,updated_at)
  values(v_user,p_category,p_item_id,now())
  on conflict(user_id,category) do update
    set item_id=excluded.item_id,updated_at=now();
  return jsonb_build_object('ok',true,'equipped',true,'item_id',p_item_id);
end;
$$;
revoke all on function private.elocoins_equip_item_impl(text,text) from public, anon;
grant execute on function private.elocoins_equip_item_impl(text,text) to authenticated;

create or replace function public.elocoins_equip_item(p_category text,p_item_id text)
returns jsonb
language sql
security invoker
set search_path = public, private
as $$ select private.elocoins_equip_item_impl(p_category,p_item_id); $$;
revoke all on function public.elocoins_equip_item(text,text) from public, anon;
grant execute on function public.elocoins_equip_item(text,text) to authenticated;

create or replace function public.elocoins_daily_summary()
returns table(balance bigint,earned_today bigint,spent_today bigint,net_today bigint,transactions_today bigint)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  with day_window as (
    select (date_trunc('day', now() at time zone 'Europe/Paris') at time zone 'Europe/Paris') as starts_at
  ), movements as (
    select coalesce(sum(case when t.amount>0 then t.amount else 0 end),0)::bigint as earned,
           coalesce(sum(case when t.amount<0 then -t.amount else 0 end),0)::bigint as spent,
           coalesce(sum(t.amount),0)::bigint as net,
           count(*)::bigint as total
      from public.elocoins_transactions t, day_window d
     where t.user_id=(select auth.uid()) and t.created_at>=d.starts_at
  ), wallet as (
    select coalesce(w.balance,0)::bigint as current_balance
      from public.elocoins_wallets w where w.user_id=(select auth.uid())
  )
  select coalesce((select current_balance from wallet),0),m.earned,m.spent,m.net,m.total from movements m;
$$;
revoke all on function public.elocoins_daily_summary() from public, anon;
grant execute on function public.elocoins_daily_summary() to authenticated;

create index if not exists elocoins_transactions_user_created_idx
  on public.elocoins_transactions(user_id,created_at desc);
create index if not exists elocoins_owned_items_user_idx
  on public.elocoins_owned_items(user_id);
