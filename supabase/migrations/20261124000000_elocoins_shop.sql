-- ELO COURSE — Boutique ELOCOINS, migration isolée
create table if not exists public.elocoins_shop_catalog (
 item_id text primary key, category text not null check(category in ('Cadres','Badges','Objectifs','Bannières')),
 name text not null, description text not null default '', price integer not null check(price>0),
 tag text not null default '', visual jsonb not null default '{}'::jsonb, active boolean not null default true,
 sort_order integer not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.elocoins_shop_inventory (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 item_id text not null references public.elocoins_shop_catalog(item_id),
 category text not null check(category in ('Cadres','Badges','Objectifs','Bannières')),
 equipped boolean not null default false, purchased_at timestamptz not null default now(), unique(user_id,item_id)
);
create unique index if not exists elocoins_shop_one_equipped_per_category on public.elocoins_shop_inventory(user_id,category) where equipped;
create index if not exists elocoins_shop_inventory_user_idx on public.elocoins_shop_inventory(user_id,purchased_at desc);
alter table public.elocoins_shop_catalog enable row level security;
alter table public.elocoins_shop_inventory enable row level security;
drop policy if exists "Catalogue boutique actif en lecture" on public.elocoins_shop_catalog;
create policy "Catalogue boutique actif en lecture" on public.elocoins_shop_catalog for select to anon,authenticated using(active=true);
drop policy if exists "Inventaire boutique personnel en lecture" on public.elocoins_shop_inventory;
create policy "Inventaire boutique personnel en lecture" on public.elocoins_shop_inventory for select to authenticated using((select auth.uid())=user_id);
revoke insert,update,delete,truncate,references,trigger on public.elocoins_shop_catalog from anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on public.elocoins_shop_inventory from anon,authenticated;
grant select on public.elocoins_shop_catalog to anon,authenticated;
grant select on public.elocoins_shop_inventory to authenticated;
insert into public.elocoins_shop_catalog(item_id,category,name,description,price,tag,visual,sort_order) values
('frame_depart_72','Cadres','Cadre Départ 72 (Émeraude)','Contour vert émeraude net pour vos profils sarthois.',30,'Sarthe 72','{"frameClass":"frame-depart-72","shortLabel":"Départ 72"}',1),
('frame_loire_blue','Cadres','Cadre Foulée Ligérienne (Bleu)','Anneau bleu ciel et azur en rotation douce.',50,'Pays de la Loire','{"frameClass":"frame-loire-blue","shortLabel":"Bleu Loire"}',2),
('frame_podium_gold','Cadres','Cadre Podium Sarthe (Or)','Halo doré pulsant pour vos chronos.',70,'Podium','{"frameClass":"frame-podium-gold","shortLabel":"Podium Or"}',3),
('frame_trail_cyan','Cadres','Cadre Trail Nocturne (Cyan)','Cercle lumineux cyan et émeraude.',85,'Course Nature','{"frameClass":"frame-trail-cyan","shortLabel":"Trail Cyan"}',4),
('frame_chrono_flame','Cadres','Cadre Flamme Chrono (Feu)','Lueur chaleureuse or et orange.',105,'Record','{"frameClass":"frame-chrono-flame","shortLabel":"Flamme Chrono"}',5),
('frame_sprint_bolt','Cadres','Cadre Éclair Sprint (Électrique)','Rayures bleu électrique et or.',120,'Vitesse','{"frameClass":"frame-sprint-bolt","shortLabel":"Éclair Sprint"}',6),
('frame_royal_crown','Cadres','Cadre Couronne Vainqueur (Royal)','Couronne dorée et anneau royal.',145,'Prestige','{"frameClass":"frame-royal-crown","shortLabel":"Couronne Or"}',7),
('frame_legend_prism','Cadres','Cadre Légende 72-53-49 (Prisme)','Dégradé prismatique animé.',175,'Régional','{"frameClass":"frame-legend-prism","shortLabel":"Prisme 72-53-49"}',8),
('badge_sarthe_72','Badges','Coureur de la Sarthe (72)','Badge départemental.',25,'Département 72','{"icon":"🏃"}',9),
('badge_mayenne_53','Badges','Foulée de Mayenne (53)','Badge des courses mayennaises.',25,'Département 53','{"icon":"🌿"}',10),
('badge_maine_loire_49','Badges','Esprit Anjou • Maine-et-Loire (49)','Badge des parcours du Maine-et-Loire.',25,'Département 49','{"icon":"💧"}',11),
('badge_bitume_route','Badges','Spécialiste Bitume & Chrono','Pour les amateurs de route.',45,'Route','{"icon":"⏱️"}',12),
('badge_trail_nature','Badges','Explorateur Trail & Sentiers','Pour les amateurs de dénivelé.',45,'Trail','{"icon":"⛰️"}',13),
('badge_peloton_100','Badges','Chouchou du Peloton','Badge honorifique communautaire.',65,'Communauté','{"icon":"💚"}',14),
('goal_sobre','Objectifs','Encadré Objectif Sobre','Contour discret pour votre objectif.',15,'Objectif','{"goalClass":"goal-style-sobre","icon":"🎯","shortLabel":"Sobre"}',15),
('goal_chrono','Objectifs','Encadré Objectif Bleu Chrono','Reflet bleu ELO COURSE.',35,'Objectif','{"goalClass":"goal-style-chrono","icon":"⚡","shortLabel":"Bleu Chrono"}',16),
('goal_trail','Objectifs','Encadré Objectif Vert Sentier','Ambiance émeraude.',40,'Objectif','{"goalClass":"goal-style-trail","icon":"🌲","shortLabel":"Vert Sentier"}',17),
('goal_or','Objectifs','Encadré Objectif Doré Défi','Finition dorée.',60,'Objectif','{"goalClass":"goal-style-or","icon":"🏆","shortLabel":"Doré Défi"}',18),
('banner_bleu_elo','Bannières','Bannière Bleu ELO COURSE','Dégradé bleu nuit et azur.',30,'Bannière','{"bannerClass":"banner-bleu-elo","icon":"🌊","shortLabel":"Bleu ELO"}',19),
('banner_emeraude_72','Bannières','Bannière Émeraude & Azur','Reflets verts et bleus.',45,'Bannière','{"bannerClass":"banner-emeraude-72","icon":"🍀","shortLabel":"Émeraude"}',20),
('banner_or_peloton','Bannières','Bannière Or & Peloton','Éclat doré discret.',65,'Bannière','{"bannerClass":"banner-or-peloton","icon":"✨","shortLabel":"Or Peloton"}',21)
on conflict(item_id) do update set category=excluded.category,name=excluded.name,description=excluded.description,price=excluded.price,tag=excluded.tag,visual=excluded.visual,sort_order=excluded.sort_order;
create or replace function public.elocoins_purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid(); v_item public.elocoins_shop_catalog%rowtype; v_balance bigint; v_tx bigint;
begin
 if v_user is null then raise exception 'Connexion requise.'; end if;
 if not exists(select 1 from public.runner_accounts where user_id=v_user and status='approved') then raise exception 'Compte coureur non validé.'; end if;
 select * into v_item from public.elocoins_shop_catalog where item_id=p_item_id and active=true;
 if not found then raise exception 'Article indisponible.'; end if;
 select balance into v_balance from public.elocoins_wallets where user_id=v_user for update;
 if not found then raise exception 'Portefeuille ELOCOINS introuvable.'; end if;
 if exists(select 1 from public.elocoins_shop_inventory where user_id=v_user and item_id=p_item_id) then raise exception 'Article déjà possédé.'; end if;
 if v_balance<v_item.price then raise exception 'Solde ELOCOINS insuffisant.'; end if;
 insert into public.elocoins_transactions(user_id,amount,transaction_type,description,event_key)
 values(v_user,-v_item.price,'shop_purchase','Boutique : '||v_item.name,'shop:v1:'||p_item_id)
 on conflict(user_id,event_key) do nothing returning id into v_tx;
 if v_tx is null then raise exception 'Cet achat a déjà été enregistré.'; end if;
 update public.elocoins_wallets set balance=balance-v_item.price,updated_at=now()
 where user_id=v_user and balance>=v_item.price returning balance into v_balance;
 if not found then raise exception 'Solde ELOCOINS insuffisant.'; end if;
 insert into public.elocoins_shop_inventory(user_id,item_id,category,equipped) values(v_user,p_item_id,v_item.category,true);
 return jsonb_build_object('item_id',p_item_id,'balance',v_balance,'transaction_id',v_tx);
end; $$;
create or replace function public.elocoins_equip_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid(); v_category text;
begin
 if v_user is null then raise exception 'Connexion requise.'; end if;
 if not exists(select 1 from public.runner_accounts where user_id=v_user and status='approved') then raise exception 'Compte coureur non validé.'; end if;
 select category into v_category from public.elocoins_shop_inventory where user_id=v_user and item_id=p_item_id;
 if not found then raise exception 'Vous ne possédez pas cet article.'; end if;
 perform 1 from public.elocoins_wallets where user_id=v_user for update;
 update public.elocoins_shop_inventory set equipped=false where user_id=v_user and category=v_category and equipped=true;
 update public.elocoins_shop_inventory set equipped=true where user_id=v_user and item_id=p_item_id;
 return jsonb_build_object('item_id',p_item_id,'category',v_category,'equipped',true);
end; $$;
create or replace function public.elocoins_daily_summary(p_days integer default 7)
returns table(day date,credits bigint,debits bigint,net bigint)
language sql stable security definer set search_path=public,pg_temp as $$
 select (t.created_at at time zone 'Europe/Paris')::date,
 coalesce(sum(t.amount) filter(where t.amount>0),0)::bigint,
 coalesce(sum(-t.amount) filter(where t.amount<0),0)::bigint,
 coalesce(sum(t.amount),0)::bigint
 from public.elocoins_transactions t where t.user_id=auth.uid()
 and t.created_at>=now()-make_interval(days=>greatest(1,least(coalesce(p_days,7),90)))
 group by 1 order by 1 desc;
$$;
revoke all on function public.elocoins_purchase_shop_item(text) from public,anon;
revoke all on function public.elocoins_equip_shop_item(text) from public,anon;
revoke all on function public.elocoins_daily_summary(integer) from public,anon;
grant execute on function public.elocoins_purchase_shop_item(text) to authenticated;
grant execute on function public.elocoins_equip_shop_item(text) to authenticated;
grant execute on function public.elocoins_daily_summary(integer) to authenticated;
