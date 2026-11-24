create index if not exists elocoins_equipment_item_id_idx
  on public.elocoins_equipment(item_id);
create index if not exists elocoins_owned_items_item_id_idx
  on public.elocoins_owned_items(item_id);
create index if not exists elocoins_owned_items_purchase_transaction_id_idx
  on public.elocoins_owned_items(purchase_transaction_id);