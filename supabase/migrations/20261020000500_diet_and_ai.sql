-- Diet filter (any / veg / nonveg), embeddings candidate widening, per-user
-- daily AI call counting. Replaces recommend_dishes / recommend_restaurants.

-- ---------------------------------------------------------------------------
-- Tunable: minimum cosine similarity for an UNTAGGED dish to be a candidate
-- in embeddings mode. Check real values with the evaluation protocol
-- (scripts/evaluate.md) and adjust here, no code change needed.
-- ---------------------------------------------------------------------------
alter table public.app_config
  add column semantic_threshold real not null default 0.60
    check (semantic_threshold between 0 and 1);

-- ---------------------------------------------------------------------------
-- ai_usage: one row per user per (India) day. Written only by claim_ai_call.
-- ---------------------------------------------------------------------------
create table public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  calls integer not null default 0 check (calls >= 0),
  primary key (user_id, day)
);

alter table public.ai_usage enable row level security;

create policy ai_usage_select_own on public.ai_usage
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.ai_usage from public, anon, authenticated;
grant select on public.ai_usage to authenticated;

-- Atomically counts one Gemini call for the signed-in user. Returns false
-- (and counts nothing) once the daily cap is reached.
create function public.claim_ai_call(p_cap integer default 15)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_day date := (now() at time zone 'Asia/Kolkata')::date;
  v_calls integer;
begin
  if v_user is null then
    return false;
  end if;

  insert into public.ai_usage as u (user_id, day, calls)
  values (v_user, v_day, 1)
  on conflict (user_id, day)
  do update set calls = u.calls + 1
    where u.calls < least(greatest(coalesce(p_cap, 15), 1), 100)
  returning u.calls into v_calls;

  return v_calls is not null;
end;
$$;

revoke execute on function public.claim_ai_call(integer) from public, anon;
grant execute on function public.claim_ai_call(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- recommend_dishes with p_diet ('any' | 'veg' | 'nonveg'); veg and nonveg are
-- strict filters.
--   p_use_embeddings = false: candidates are dishes tagged with the mood only
--     (SQL baseline; semantic and personalization terms are 0).
--   p_use_embeddings = true: candidates are dishes tagged with the mood OR
--     whose cosine similarity to the mood embedding is >= semantic_threshold.
--     Untagged dishes get mood_fit = 0. If the mood has no embedding yet, only
--     tagged dishes are candidates.
-- Same weights from app_config. p_limit defaults to 20 and is capped at 50.
-- ---------------------------------------------------------------------------
drop function public.recommend_restaurants(text, double precision, double precision, integer, boolean, integer);
drop function public.recommend_dishes(text, double precision, double precision, integer, boolean, boolean, integer);

create function public.recommend_dishes(
  p_mood_id text,
  p_lat double precision,
  p_lng double precision,
  p_max_price integer default null,
  p_diet text default 'any',
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
  v_diet text := coalesce(p_diet, 'any');
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  if v_diet not in ('any', 'veg', 'nonveg') then
    raise exception 'Unknown diet' using errcode = '22023';
  end if;

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
  with base as (
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
      coalesce(dm.weight, 0)::double precision as c_fit,
      (dm.dish_id is not null) as c_tagged,
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
    left join public.dish_moods dm on dm.dish_id = d.id and dm.mood_id = p_mood_id
    where r.is_open
      and (p_max_price is null or d.price_inr <= p_max_price)
      and (v_diet = 'any' or (v_diet = 'veg' and d.is_veg) or (v_diet = 'nonveg' and not d.is_veg))
  ),
  candidates as (
    select b.*
    from base b
    where b.c_tagged
      or (p_use_embeddings and v_mood_embedding is not null and b.c_sem >= v_cfg.semantic_threshold)
  )
  select
    c.c_dish_id,
    c.c_dish_name,
    c.c_description,
    c.c_price,
    c.c_is_veg,
    c.c_category,
    c.c_restaurant_id,
    c.c_restaurant_name,
    c.c_area,
    c.c_km,
    c.c_fit,
    c.c_sem,
    c.c_pers,
    exp(-c.c_km / v_cfg.distance_scale_km),
    (v_cfg.w_mood_fit * c.c_fit
      + v_cfg.w_semantic * c.c_sem
      + v_cfg.w_personal * c.c_pers
      + v_cfg.w_distance * exp(-c.c_km / v_cfg.distance_scale_km))::double precision
  from candidates c
  order by 15 desc, c.c_km asc, c.c_dish_id
  limit v_limit;
end;
$$;

-- ---------------------------------------------------------------------------
-- recommend_restaurants: restaurants ranked by their best dish score.
-- Looks at the 50 best dishes (the cap of recommend_dishes).
-- ---------------------------------------------------------------------------
create function public.recommend_restaurants(
  p_mood_id text,
  p_lat double precision,
  p_lng double precision,
  p_max_price integer default null,
  p_diet text default 'any',
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
    from public.recommend_dishes(p_mood_id, p_lat, p_lng, p_max_price, p_diet, true, 50) rd
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

revoke execute on function public.recommend_dishes(text, double precision, double precision, integer, text, boolean, integer) from public;
revoke execute on function public.recommend_restaurants(text, double precision, double precision, integer, text, integer) from public;
grant execute on function public.recommend_dishes(text, double precision, double precision, integer, text, boolean, integer) to anon, authenticated;
grant execute on function public.recommend_restaurants(text, double precision, double precision, integer, text, integer) to anon, authenticated;
