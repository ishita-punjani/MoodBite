-- RPCs: Mumbai zone check, recommendation scoring, order placement.
-- All weights live in public.app_config (see 20261020000100_schema.sql).

-- ---------------------------------------------------------------------------
-- nearest_zone: the closest delivery zone within app_config.zone_radius_km,
-- or no row if the point is outside Mumbai.
-- ---------------------------------------------------------------------------
create function public.nearest_zone(p_lat double precision, p_lng double precision)
returns table (zone_id text, zone_name text, distance_km double precision)
language sql
stable
set search_path = public, extensions
as $$
  with p as (
    select st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography as g
  )
  select z.id, z.name, st_distance(z.location, p.g) / 1000.0
  from public.zones z
  cross join p
  cross join public.app_config c
  where st_dwithin(z.location, p.g, c.zone_radius_km * 1000.0)
  order by 3
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Addresses must be inside a zone; zone_id is always set by the server.
-- ---------------------------------------------------------------------------
create function public.addresses_set_zone()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  select nz.zone_id into new.zone_id
  from public.nearest_zone(new.lat, new.lng) nz;

  if new.zone_id is null then
    raise exception 'We deliver only in Mumbai' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger addresses_set_zone
  before insert or update of lat, lng on public.addresses
  for each row execute function public.addresses_set_zone();

-- ---------------------------------------------------------------------------
-- recommend_dishes: hard filters + weighted score.
--   score = w_mood_fit * mood_fit + w_semantic * semantic_sim
--         + w_personal * personalization + w_distance * exp(-km / distance_scale_km)
-- Only dishes tagged with the chosen mood are candidates.
-- p_use_embeddings = false gives the SQL-only baseline (semantic and
-- personalization terms are 0) used in the report's evaluation.
-- ---------------------------------------------------------------------------
create function public.recommend_dishes(
  p_mood_id text,
  p_lat double precision,
  p_lng double precision,
  p_max_price integer default null,
  p_veg_only boolean default false,
  p_use_embeddings boolean default true,
  p_limit integer default 20
)
returns table (
  dish_id text,
  dish_name text,
  description text,
  price_inr integer,
  is_veg boolean,
  category text,
  restaurant_id text,
  restaurant_name text,
  area text,
  distance_km double precision,
  mood_fit double precision,
  semantic_sim double precision,
  personalization double precision,
  distance_decay double precision,
  score double precision
)
language plpgsql
stable
set search_path = public, extensions
as $$
#variable_conflict use_column
declare
  v_cfg public.app_config%rowtype;
  v_point extensions.geography;
  v_mood_embedding extensions.vector(768);
  v_user_embedding extensions.vector(768);
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 500);
begin
  if p_max_price is not null and (p_max_price < 1 or p_max_price > 5000) then
    raise exception 'Enter a price between 1 and 5000' using errcode = '22023';
  end if;

  if not exists (select 1 from public.moods m where m.id = p_mood_id) then
    raise exception 'Unknown mood' using errcode = '22023';
  end if;

  if not exists (select 1 from public.nearest_zone(p_lat, p_lng)) then
    raise exception 'We deliver only in Mumbai' using errcode = 'P0001';
  end if;

  select * into v_cfg from public.app_config limit 1;
  v_point := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;

  if p_use_embeddings then
    select m.embedding into v_mood_embedding
    from public.moods m
    where m.id = p_mood_id;

    if auth.uid() is not null then
      select avg(d.embedding) into v_user_embedding
      from public.orders o
      join public.order_items oi on oi.order_id = o.id
      join public.dishes d on d.id = oi.dish_id
      where o.user_id = auth.uid()
        and d.embedding is not null;
    end if;
  end if;

  return query
  with candidates as (
    select
      d.id as c_dish_id,
      d.name as c_dish_name,
      d.description as c_description,
      d.price_inr as c_price,
      d.is_veg as c_is_veg,
      d.category as c_category,
      r.id as c_restaurant_id,
      r.name as c_restaurant_name,
      r.area as c_area,
      st_distance(r.location, v_point) / 1000.0 as c_km,
      dm.weight::double precision as c_fit,
      case
        when v_mood_embedding is null or d.embedding is null then 0.0::double precision
        else greatest(0.0::double precision, 1.0 - (d.embedding <=> v_mood_embedding))
      end as c_sem,
      case
        when v_user_embedding is null or d.embedding is null then 0.0::double precision
        else greatest(0.0::double precision, 1.0 - (d.embedding <=> v_user_embedding))
      end as c_pers
    from public.dishes d
    join public.restaurants r on r.id = d.restaurant_id
    join public.dish_moods dm on dm.dish_id = d.id and dm.mood_id = p_mood_id
    where r.is_open
      and (p_max_price is null or d.price_inr <= p_max_price)
      and (not coalesce(p_veg_only, false) or d.is_veg)
  ),
  scored as (
    select
      c.*,
      exp(-c.c_km / v_cfg.distance_scale_km) as c_decay
    from candidates c
  )
  select
    s.c_dish_id,
    s.c_dish_name,
    s.c_description,
    s.c_price,
    s.c_is_veg,
    s.c_category,
    s.c_restaurant_id,
    s.c_restaurant_name,
    s.c_area,
    s.c_km,
    s.c_fit,
    s.c_sem,
    s.c_pers,
    s.c_decay,
    (v_cfg.w_mood_fit * s.c_fit
      + v_cfg.w_semantic * s.c_sem
      + v_cfg.w_personal * s.c_pers
      + v_cfg.w_distance * s.c_decay)::double precision
  from scored s
  order by 15 desc, s.c_km asc, s.c_dish_id
  limit v_limit;
end;
$$;

-- ---------------------------------------------------------------------------
-- recommend_restaurants: restaurants ranked by their best dish score.
-- ---------------------------------------------------------------------------
create function public.recommend_restaurants(
  p_mood_id text,
  p_lat double precision,
  p_lng double precision,
  p_max_price integer default null,
  p_veg_only boolean default false,
  p_limit integer default 10
)
returns table (
  restaurant_id text,
  restaurant_name text,
  area text,
  distance_km double precision,
  best_score double precision,
  best_dish_id text,
  best_dish_name text
)
language sql
stable
set search_path = public, extensions
as $$
  with ranked as (
    select
      rd.*,
      row_number() over (partition by rd.restaurant_id order by rd.score desc) as rn
    from public.recommend_dishes(p_mood_id, p_lat, p_lng, p_max_price, p_veg_only, true, 500) rd
  )
  select
    x.restaurant_id,
    x.restaurant_name,
    x.area,
    x.distance_km,
    x.score,
    x.dish_id,
    x.dish_name
  from ranked x
  where x.rn = 1
  order by x.score desc, x.distance_km asc
  limit least(greatest(coalesce(p_limit, 10), 1), 50);
$$;

-- ---------------------------------------------------------------------------
-- place_order: validates everything server-side and computes the total from
-- catalogue prices. p_items = [{"dish_id": "d001", "qty": 2}, ...]
-- ---------------------------------------------------------------------------
create function public.place_order(
  p_address_id uuid,
  p_restaurant_id text,
  p_items jsonb,
  p_mood_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user uuid := auth.uid();
  v_addr public.addresses%rowtype;
  v_order_id uuid;
  v_item_count integer;
  v_valid_count integer;
  v_distinct_count integer;
  v_total integer;
begin
  if v_user is null then
    raise exception 'Please sign in to place an order' using errcode = '28000';
  end if;

  select * into v_addr
  from public.addresses a
  where a.id = p_address_id and a.user_id = v_user;
  if not found then
    raise exception 'Choose a delivery address' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.nearest_zone(v_addr.lat, v_addr.lng)) then
    raise exception 'We deliver only in Mumbai' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.restaurants r where r.id = p_restaurant_id and r.is_open
  ) then
    raise exception 'This restaurant is not taking orders right now' using errcode = 'P0001';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty' using errcode = 'P0001';
  end if;

  if jsonb_array_length(p_items) > 30 then
    raise exception 'Too many items in one order' using errcode = 'P0001';
  end if;

  select
    count(*),
    count(d.id) filter (where i.qty between 1 and 10),
    count(distinct i.dish_id),
    coalesce(sum(d.price_inr * i.qty) filter (where i.qty between 1 and 10), 0)
  into v_item_count, v_valid_count, v_distinct_count, v_total
  from (
    select
      e.item ->> 'dish_id' as dish_id,
      case
        when (e.item ->> 'qty') ~ '^[0-9]{1,2}$' then (e.item ->> 'qty')::integer
      end as qty
    from jsonb_array_elements(p_items) as e(item)
  ) i
  left join public.dishes d
    on d.id = i.dish_id and d.restaurant_id = p_restaurant_id;

  if v_valid_count <> v_item_count then
    raise exception 'Quantity must be between 1 and 10, and all items must be from this restaurant'
      using errcode = 'P0001';
  end if;

  if v_distinct_count <> v_item_count then
    raise exception 'Each dish can appear only once in an order' using errcode = 'P0001';
  end if;

  insert into public.orders (user_id, restaurant_id, address_id, delivery_lat, delivery_lng, total)
  values (v_user, p_restaurant_id, v_addr.id, v_addr.lat, v_addr.lng, v_total)
  returning id into v_order_id;

  insert into public.order_items (order_id, dish_id, qty, price_at_order)
  select v_order_id, d.id, (e.item ->> 'qty')::integer, d.price_inr
  from jsonb_array_elements(p_items) as e(item)
  join public.dishes d on d.id = e.item ->> 'dish_id';

  if p_mood_id is not null and exists (select 1 from public.moods m where m.id = p_mood_id) then
    insert into public.recommendation_feedback (user_id, dish_id, mood_id, action)
    select v_user, e.item ->> 'dish_id', p_mood_id, 'ordered'
    from jsonb_array_elements(p_items) as e(item);
  end if;

  return v_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Execute permissions
-- ---------------------------------------------------------------------------
revoke execute on function public.nearest_zone(double precision, double precision) from public;
revoke execute on function public.recommend_dishes(text, double precision, double precision, integer, boolean, boolean, integer) from public;
revoke execute on function public.recommend_restaurants(text, double precision, double precision, integer, boolean, integer) from public;
revoke execute on function public.place_order(uuid, text, jsonb, text) from public, anon;
-- Trigger-only; EXECUTE is checked when the trigger is created, not when it fires.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

grant execute on function public.nearest_zone(double precision, double precision) to anon, authenticated;
grant execute on function public.recommend_dishes(text, double precision, double precision, integer, boolean, boolean, integer) to anon, authenticated;
grant execute on function public.recommend_restaurants(text, double precision, double precision, integer, boolean, integer) to anon, authenticated;
grant execute on function public.place_order(uuid, text, jsonb, text) to authenticated;
