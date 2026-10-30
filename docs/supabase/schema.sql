-- Supabase schema for mc-launcher profiles.
--
-- HOW TO USE:
--   1. Open the Supabase project, go to SQL Editor, paste this whole file and run it once.
--   2. Go to Authentication > Providers and enable: Email, Google, Azure (Microsoft), Discord.
--   3. Go to Authentication > URL Configuration and add this redirect URL to the allow-list:
--        http://127.0.0.1:54545/callback
--
-- The script is idempotent: it can be re-run safely after partial failures.

-- 1. Profiles table -----------------------------------------------------

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    tag text not null unique check (tag ~ '^[a-z0-9_]{3,16}$'),
    display_name text not null check (char_length(display_name) between 1 and 32),
    bio text not null default '' check (char_length(bio) <= 200),
    avatar_name text check (char_length(avatar_name) <= 16),
    show_online_status boolean not null default true,
    friend_requests text not null default 'everyone' check (friend_requests in ('everyone', 'nobody')),
    profile_visibility text not null default 'public' check (profile_visibility in ('public', 'friends', 'private')),
    show_stats boolean not null default true,
    playtime_minutes bigint not null default 0 check (playtime_minutes >= 0),
    instances_count int not null default 0 check (instances_count >= 0),
    mods_count int not null default 0 check (mods_count >= 0),
    favorite_pack text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2. updated_at trigger ---------------------------------------------------

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists set_updated_at on public.profiles;
create trigger set_updated_at
    before update on public.profiles
    for each row
    execute function public.handle_updated_at();

-- 3. Row level security ----------------------------------------------------

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own_or_public" on public.profiles;
create policy "profiles_select_own_or_public"
    on public.profiles
    for select
    using (id = auth.uid() or profile_visibility = 'public');

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
    on public.profiles
    for insert
    with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
    on public.profiles
    for update
    using (id = auth.uid())
    with check (id = auth.uid());

-- No delete policy: profiles are removed via the auth.users cascade only.

-- 4. New user bootstrap -----------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    candidate_tag text;
    final_tag text;
    raw_display_name text;
    final_display_name text;
begin
    -- Try the tag requested at sign-up time.
    candidate_tag := lower(coalesce(new.raw_user_meta_data->>'tag', ''));

    if candidate_tag ~ '^[a-z0-9_]{3,16}$'
       and not exists (select 1 from public.profiles where tag = candidate_tag) then
        final_tag := candidate_tag;
    else
        -- Generate a free random tag.
        loop
            final_tag := 'user' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
            if not exists (select 1 from public.profiles where tag = final_tag) then
                exit;
            end if;
        end loop;
    end if;

    -- Pick a display name from the available metadata, falling back to the email or the tag.
    raw_display_name := coalesce(
        new.raw_user_meta_data->>'display_name',
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'name',
        split_part(new.email, '@', 1),
        final_tag
    );
    final_display_name := trim(raw_display_name);
    if char_length(final_display_name) = 0 then
        final_display_name := final_tag;
    end if;
    final_display_name := substr(final_display_name, 1, 32);

    insert into public.profiles (id, tag, display_name)
    values (new.id, final_tag, final_display_name);

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- 5. Tag availability check for the sign-up UI ------------------------------

create or replace function public.tag_available(t text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select lower(t) ~ '^[a-z0-9_]{3,16}$'
        and not exists (select 1 from public.profiles where tag = lower(t));
$$;

grant execute on function public.tag_available(text) to anon, authenticated;
