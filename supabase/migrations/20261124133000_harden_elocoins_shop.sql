-- ELO COURSE — durcissement des accès de la boutique ELOCOINS
-- Rend explicites les privilèges et le search_path des fonctions à privilèges élevés.
alter function private.elocoins_purchase_item_impl(text, uuid) set search_path = '';
alter function private.elocoins_equip_item_impl(text, text) set search_path = '';
alter function public.elocoins_purchase_item(text, uuid) set search_path = '';
alter function public.elocoins_equip_item(text, text) set search_path = '';
alter function public.elocoins_daily_summary() set search_path = '';

revoke all on table public.elocoins_catalog from anon, authenticated;
grant select on table public.elocoins_catalog to anon, authenticated;
revoke all on table public.elocoins_owned_items from anon, authenticated;
grant select on table public.elocoins_owned_items to authenticated;
revoke all on table public.elocoins_equipment from anon, authenticated;
grant select on table public.elocoins_equipment to authenticated;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke all on function private.elocoins_purchase_item_impl(text, uuid) from public, anon;
grant execute on function private.elocoins_purchase_item_impl(text, uuid) to authenticated;
revoke all on function private.elocoins_equip_item_impl(text, text) from public, anon;
grant execute on function private.elocoins_equip_item_impl(text, text) to authenticated;
