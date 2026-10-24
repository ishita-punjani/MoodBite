-- Read-only checks to paste into the Supabase SQL editor AFTER the migrations
-- (and later the seed) have been applied. Nothing here changes data.

-- 1. Extensions present
select extname, extversion from pg_extension where extname in ('postgis', 'vector');

-- 2. RLS enabled on every app table (expect rowsecurity = true for all)
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;

-- 3. Zones loaded (expect 27)
select count(*) as zones from public.zones;

-- 4. Zone check: Bandra (expect Bandra West) and San Francisco (expect no row)
select * from public.nearest_zone(19.0596, 72.8295);
select * from public.nearest_zone(37.7749, -122.4194);

-- 5. After seeding: catalogue counts (expect 50 restaurants, 8 moods)
select
  (select count(*) from public.restaurants) as restaurants,
  (select count(*) from public.dishes) as dishes,
  (select count(*) from public.moods) as moods,
  (select count(*) from public.dish_moods) as dish_moods;

-- 6. After seeding: SQL-only baseline recommendations for "happy" near Bandra
select dish_name, restaurant_name, price_inr, round(distance_km::numeric, 1) as km, round(score::numeric, 3) as score
from public.recommend_dishes('happy', 19.0596, 72.8295, null, 'any', false, 10);

-- 7. Same with a price cap and veg only (expect every price_inr <= 200 and is_veg = true)
select dish_name, price_inr, is_veg
from public.recommend_dishes('stressed', 19.0178, 72.8478, 200, 'veg', false, 10);

-- 8. Restaurants ranked by best dish
select * from public.recommend_restaurants('romantic', 18.9322, 72.8347);
