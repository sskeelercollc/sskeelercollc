
-- INCOR DISCS: The Flight Log
-- Run in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  category text not null
    check (category in ('courses','gear','tournaments','culture','news')),
  excerpt text not null default '',
  content text not null default '',
  cover_image_path text,
  cover_alt text not null default '',
  status text not null default 'draft'
    check (status in ('draft','published')),
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

alter table public.posts enable row level security;
alter table public.post_images enable row level security;

-- Public visitors can read published stories only.
create policy "Public read published posts"
on public.posts for select to anon, authenticated
using (status = 'published');

-- Signed-in writers can manage stories.
-- Keep public sign-ups disabled and only create trusted writer accounts.
create policy "Writers manage posts"
on public.posts for all to authenticated
using (auth.uid() is not null)
with check (auth.uid() is not null);

-- Public visitors can see gallery records for published stories.
create policy "Public read published gallery"
on public.post_images for select to anon, authenticated
using (
  exists (
    select 1 from public.posts p
    where p.id = post_id and p.status = 'published'
  )
);

create policy "Writers manage gallery"
on public.post_images for all to authenticated
using (auth.uid() is not null)
with check (auth.uid() is not null);

-- Public image bucket. Readers can view images; writers can upload/delete.
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'flight-log',
  'flight-log',
  true,
  12582912,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/avif'
  ]
)
on conflict (id) do update set
  public = true,
  file_size_limit = 12582912,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/avif'
  ];

create policy "Public view Flight Log images"
on storage.objects for select to anon, authenticated
using (bucket_id = 'flight-log');

create policy "Writers upload Flight Log images"
on storage.objects for insert to authenticated
with check (bucket_id = 'flight-log' and auth.uid() is not null);

create policy "Writers update Flight Log images"
on storage.objects for update to authenticated
using (bucket_id = 'flight-log' and auth.uid() is not null)
with check (bucket_id = 'flight-log' and auth.uid() is not null);

create policy "Writers delete Flight Log images"
on storage.objects for delete to authenticated
using (bucket_id = 'flight-log' and auth.uid() is not null);

create index if not exists posts_status_published_at_idx
on public.posts (status, published_at desc);

create index if not exists post_images_post_sort_idx
on public.post_images (post_id, sort_order);
