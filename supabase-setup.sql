-- Run once in the Supabase SQL Editor.
-- This version restricts content and image management to users listed in public.flight_log_writers.
create extension if not exists pgcrypto;
create table if not exists public.flight_log_writers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  category text not null check (category in ('courses','gear','tournaments','culture','news')),
  excerpt text not null default '',
  content text not null default '',
  cover_image_path text,
  cover_alt text not null default '',
  status text not null default 'draft' check (status in ('draft','published')),
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.post_images (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  storage_path text not null,
  alt_text text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists posts_publication_idx on public.posts(status, published_at desc);
create index if not exists post_images_order_idx on public.post_images(post_id, sort_order);
alter table public.flight_log_writers enable row level security;
alter table public.posts enable row level security;
alter table public.post_images enable row level security;
drop policy if exists "Writers can read their own writer access" on public.flight_log_writers;
create policy "Writers can read their own writer access" on public.flight_log_writers for select to authenticated using (user_id=auth.uid());
drop policy if exists "Public reads published posts" on public.posts;
create policy "Public reads published posts" on public.posts for select to anon, authenticated using (status='published' or exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Writers insert posts" on public.posts;
create policy "Writers insert posts" on public.posts for insert to authenticated with check (exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Writers update posts" on public.posts;
create policy "Writers update posts" on public.posts for update to authenticated using (exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid())) with check (exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Writers delete posts" on public.posts;
create policy "Writers delete posts" on public.posts for delete to authenticated using (exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Public reads gallery for published posts" on public.post_images;
create policy "Public reads gallery for published posts" on public.post_images for select to anon, authenticated using (exists(select 1 from public.posts p where p.id=post_id and p.status='published') or exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Writers manage gallery" on public.post_images;
create policy "Writers manage gallery" on public.post_images for all to authenticated using (exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid())) with check (exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('flight-log','flight-log',true,12582912,array['image/jpeg','image/png','image/webp','image/gif','image/avif']) on conflict(id) do update set public=true,file_size_limit=12582912,allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif','image/avif'];
drop policy if exists "Public reads Flight Log images" on storage.objects;
create policy "Public reads Flight Log images" on storage.objects for select to anon, authenticated using (bucket_id='flight-log');
drop policy if exists "Writers upload Flight Log images" on storage.objects;
create policy "Writers upload Flight Log images" on storage.objects for insert to authenticated with check (bucket_id='flight-log' and exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Writers update Flight Log images" on storage.objects;
create policy "Writers update Flight Log images" on storage.objects for update to authenticated using (bucket_id='flight-log' and exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid())) with check (bucket_id='flight-log' and exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
drop policy if exists "Writers delete Flight Log images" on storage.objects;
create policy "Writers delete Flight Log images" on storage.objects for delete to authenticated using (bucket_id='flight-log' and exists(select 1 from public.flight_log_writers w where w.user_id=auth.uid()));
-- After creating your writer user in Authentication > Users, run the separate INSERT below with that user's UUID:
-- insert into public.flight_log_writers(user_id) values ('PASTE-AUTH-USER-UUID-HERE');
