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

-- 6. Account deletion -------------------------------------------------------

create or replace function public.delete_own_account()
returns void
language sql
security definer
set search_path = public
as $$
    delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

-- 7. Friends and presence ---------------------------------------------------
-- Tables have RLS enabled and NO policies: the app reads and writes only through
-- the security definer functions below, so nothing else is exposed.

create table if not exists public.friendships (
    requester uuid not null references auth.users(id) on delete cascade,
    addressee uuid not null references auth.users(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted')),
    created_at timestamptz not null default now(),
    primary key (requester, addressee),
    check (requester <> addressee)
);

-- One row per pair, whichever side asked first.
create unique index if not exists friendships_pair_idx
    on public.friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee_idx on public.friendships (addressee);

create table if not exists public.presence (
    user_id uuid primary key references auth.users(id) on delete cascade,
    last_seen_at timestamptz not null default now(),
    activity text check (char_length(activity) <= 80)
);

alter table public.friendships enable row level security;
alter table public.presence enable row level security;

-- Heartbeat: the app calls this every ~30 s while open. activity = null means "just online".
create or replace function public.set_presence(p_activity text default null)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.presence (user_id, last_seen_at, activity)
    values (auth.uid(), now(), nullif(left(trim(coalesce(p_activity, '')), 80), ''))
    on conflict (user_id) do update
        set last_seen_at = now(), activity = excluded.activity;
$$;

-- Friends, incoming and outgoing requests in one call.
-- Presence is shown only for accepted friends and only if they allow it.
create or replace function public.friends_overview()
returns table (
    user_id uuid,
    tag text,
    display_name text,
    avatar_name text,
    relation text,
    online boolean,
    activity text,
    last_seen_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
    select
        p.id,
        p.tag,
        p.display_name,
        p.avatar_name,
        case
            when f.status = 'accepted' then 'friend'
            when f.addressee = auth.uid() then 'incoming'
            else 'outgoing'
        end,
        (f.status = 'accepted' and p.show_online_status and pr.last_seen_at > now() - interval '90 seconds'),
        case when f.status = 'accepted' and p.show_online_status
                  and pr.last_seen_at > now() - interval '90 seconds' then pr.activity end,
        case when f.status = 'accepted' and p.show_online_status then pr.last_seen_at end
    from public.friendships f
    join public.profiles p
        on p.id = case when f.requester = auth.uid() then f.addressee else f.requester end
    left join public.presence pr on pr.user_id = p.id
    where auth.uid() in (f.requester, f.addressee);
$$;

-- Send a request by tag. If the other person already asked us, accept instead.
-- Returns: 'sent', 'accepted', 'not_found', 'closed', 'exists', 'self', 'limit'.
create or replace function public.send_friend_request(p_tag text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    target public.profiles%rowtype;
    existing public.friendships%rowtype;
begin
    if me is null then
        return 'not_found';
    end if;
    select * into target from public.profiles where tag = lower(trim(p_tag));
    if not found then
        return 'not_found';
    end if;
    if target.id = me then
        return 'self';
    end if;

    select * into existing from public.friendships
    where (requester = me and addressee = target.id) or (requester = target.id and addressee = me);

    if found then
        if existing.status = 'pending' and existing.addressee = me then
            update public.friendships set status = 'accepted'
            where requester = existing.requester and addressee = existing.addressee;
            return 'accepted';
        end if;
        return 'exists';
    end if;

    if target.friend_requests = 'nobody' then
        return 'closed';
    end if;
    if (select count(*) from public.friendships where requester = me and status = 'pending') >= 50 then
        return 'limit';
    end if;

    insert into public.friendships (requester, addressee) values (me, target.id);
    return 'sent';
end;
$$;

-- Answer an incoming request: accept keeps it, decline deletes it.
create or replace function public.respond_friend_request(p_user uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_accept then
        update public.friendships set status = 'accepted'
        where requester = p_user and addressee = auth.uid() and status = 'pending';
    else
        delete from public.friendships
        where requester = p_user and addressee = auth.uid() and status = 'pending';
    end if;
end;
$$;

-- Remove a friend, cancel an outgoing request, or drop any row with that person.
create or replace function public.remove_friend(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.friendships
    where (requester = auth.uid() and addressee = p_user)
       or (requester = p_user and addressee = auth.uid());
$$;

revoke all on function public.set_presence(text) from public, anon;
revoke all on function public.friends_overview() from public, anon;
revoke all on function public.send_friend_request(text) from public, anon;
revoke all on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.set_presence(text) to authenticated;
grant execute on function public.friends_overview() to authenticated;
grant execute on function public.send_friend_request(text) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
