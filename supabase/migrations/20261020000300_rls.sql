-- Row level security.
-- Catalogue: anyone can read, nobody can write through the API (service role bypasses RLS).
-- User tables: each user sees and changes only their own rows.
-- Orders and order items are written only by the place_order RPC (security definer),
-- so clients cannot set their own totals or prices.

alter table public.app_config enable row level security;
alter table public.moods enable row level security;
alter table public.zones enable row level security;
alter table public.restaurants enable row level security;
alter table public.dishes enable row level security;
alter table public.dish_moods enable row level security;
alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.recommendation_feedback enable row level security;

-- Catalogue: public read
create policy "Public read" on public.app_config for select to anon, authenticated using (true);
create policy "Public read" on public.moods for select to anon, authenticated using (true);
create policy "Public read" on public.zones for select to anon, authenticated using (true);
create policy "Public read" on public.restaurants for select to anon, authenticated using (true);
create policy "Public read" on public.dishes for select to anon, authenticated using (true);
create policy "Public read" on public.dish_moods for select to anon, authenticated using (true);

-- Profiles (row is created by the signup trigger)
create policy "Own profile read" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Own profile insert" on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "Own profile update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Addresses
create policy "Own addresses read" on public.addresses
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Own addresses insert" on public.addresses
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Own addresses update" on public.addresses
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "Own addresses delete" on public.addresses
  for delete to authenticated using (user_id = (select auth.uid()));

-- Orders: read only (writes go through place_order)
create policy "Own orders read" on public.orders
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Own order items read" on public.order_items
  for select to authenticated using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id and o.user_id = (select auth.uid())
    )
  );

-- Recommendation feedback
create policy "Own feedback read" on public.recommendation_feedback
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Own feedback insert" on public.recommendation_feedback
  for insert to authenticated with check (user_id = (select auth.uid()));

-- Explicit grants, in case the project does not grant new public tables to API roles by default.
grant usage on schema public to anon, authenticated;
grant select on public.app_config, public.moods, public.zones, public.restaurants,
  public.dishes, public.dish_moods to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.addresses to authenticated;
grant select on public.orders, public.order_items to authenticated;
grant select, insert on public.recommendation_feedback to authenticated;
