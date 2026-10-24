-- MoodBite schema: extensions, catalogue tables, user tables, indexes.
-- Text IDs for catalogue rows (r001, d001) so CSV import is easy.

create extension if not exists postgis with schema extensions;
create extension if not exists vector with schema extensions;

-- ---------------------------------------------------------------------------
-- Recommendation and delivery-zone settings (single row, documented in report)
-- ---------------------------------------------------------------------------
create table public.app_config (
  id boolean primary key default true check (id),
  w_mood_fit real not null default 0.40,
  w_semantic real not null default 0.25,
  w_personal real not null default 0.15,
  w_distance real not null default 0.20,
  distance_scale_km real not null default 3.0,  -- distance_decay = exp(-km / scale)
  zone_radius_km real not null default 5.0      -- a point is "in Mumbai" if within this of a zone centre
);

insert into public.app_config (id) values (true);

-- ---------------------------------------------------------------------------
-- Catalogue (public read, service-role write)
-- ---------------------------------------------------------------------------
create table public.moods (
  id text primary key,
  label text not null,
  emoji text not null,
  description text not null default '',
  embedding extensions.vector(768)
);

create table public.zones (
  id text primary key,
  name text not null unique,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  location extensions.geography(Point, 4326)
    generated always as (
      extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
    ) stored
);

create table public.restaurants (
  id text primary key,
  name text not null,
  area text not null,
  address text not null,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  location extensions.geography(Point, 4326)
    generated always as (
      extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
    ) stored,
  cuisine text[] not null default '{}',
  price_level smallint not null check (price_level between 1 and 4),
  is_open boolean not null default true,
  coords_verified boolean not null default false
);

create table public.dishes (
  id text primary key,
  restaurant_id text not null references public.restaurants (id) on delete cascade,
  name text not null,
  description text not null default '',
  price_inr integer not null check (price_inr > 0),
  is_veg boolean not null,
  category text not null,
  image_url text,
  embedding extensions.vector(768)
);

create table public.dish_moods (
  dish_id text not null references public.dishes (id) on delete cascade,
  mood_id text not null references public.moods (id) on delete cascade,
  weight real not null check (weight > 0 and weight <= 1),
  primary key (dish_id, mood_id)
);

-- ---------------------------------------------------------------------------
-- User data (owner-only access via RLS)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (full_name is null or char_length(full_name) between 2 and 50),
  phone text check (phone is null or phone ~ '^[6-9][0-9]{9}$'),
  is_veg boolean,
  liked_cuisines text[] not null default '{}',
  default_max_price integer check (default_max_price is null or default_max_price between 1 and 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  label text not null default 'Home',
  line1 text not null check (char_length(trim(line1)) >= 5),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  zone_id text references public.zones (id),
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  restaurant_id text not null references public.restaurants (id),
  address_id uuid references public.addresses (id) on delete set null,
  -- Delivery point is copied from the address so tracking still works if the address is deleted.
  delivery_lat double precision not null,
  delivery_lng double precision not null,
  total integer not null check (total > 0),
  status text not null default 'placed'
    check (status in ('placed', 'preparing', 'picked_up', 'on_the_way', 'delivered')),
  placed_at timestamptz not null default now()
);

create table public.order_items (
  order_id uuid not null references public.orders (id) on delete cascade,
  dish_id text not null references public.dishes (id),
  qty integer not null check (qty between 1 and 10),
  price_at_order integer not null check (price_at_order > 0),
  primary key (order_id, dish_id)
);

create table public.recommendation_feedback (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  dish_id text not null references public.dishes (id) on delete cascade,
  mood_id text not null references public.moods (id) on delete cascade,
  action text not null check (action in ('ordered', 'skipped', 'liked')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index restaurants_location_idx on public.restaurants using gist (location);
create index zones_location_idx on public.zones using gist (location);
create index dishes_restaurant_idx on public.dishes (restaurant_id);
create index dish_moods_mood_idx on public.dish_moods (mood_id);
create index addresses_user_idx on public.addresses (user_id);
create index orders_user_idx on public.orders (user_id, placed_at desc);
create index order_items_dish_idx on public.order_items (dish_id);
create index feedback_user_idx on public.recommendation_feedback (user_id);

-- ---------------------------------------------------------------------------
-- Profile row is created automatically when a user signs up.
-- ---------------------------------------------------------------------------
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();
