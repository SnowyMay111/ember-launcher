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

-- 8. Lobbies ------------------------------------------------------------------
-- Same model as section 7: RLS on, no policies, everything through security definer functions.
-- The host's public address (relay) is revealed only by join_lobby / lobby_info to people allowed in.
-- A lobby counts as alive while its host sends lobby_heartbeat at least every 3 minutes.

create table if not exists public.lobbies (
    id uuid primary key default gen_random_uuid(),
    host uuid not null references auth.users(id) on delete cascade,
    code text not null unique check (code ~ '^[A-Z0-9]{6}$'),
    name text not null check (char_length(name) between 1 and 40),
    mc_version text not null check (char_length(mc_version) <= 32),
    loader text not null check (loader in ('fabric', 'quilt', 'neoforge', 'forge', 'vanilla')),
    pack_url text check (char_length(pack_url) <= 20000),
    pack_sha1 text check (pack_sha1 ~ '^[0-9a-f]{40}$'),
    privacy text not null default 'friends' check (privacy in ('friends', 'invite')),
    max_players int not null default 8 check (max_players between 2 and 16),
    address text check (char_length(address) <= 120),
    status text not null default 'starting' check (status in ('starting', 'open', 'closed')),
    created_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now()
);

create table if not exists public.lobby_members (
    lobby_id uuid not null references public.lobbies(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    nick text not null check (nick ~ '^[A-Za-z0-9_]{3,16}$'),
    state text not null default 'joined' check (state in ('invited', 'joined')),
    created_at timestamptz not null default now(),
    primary key (lobby_id, user_id)
);

-- One nickname per lobby, case-insensitive: nicks are what the game server whitelists.
create unique index if not exists lobby_members_nick_idx on public.lobby_members (lobby_id, lower(nick));
create index if not exists lobby_members_user_idx on public.lobby_members (user_id);
create index if not exists lobbies_host_idx on public.lobbies (host);

alter table public.lobbies enable row level security;
alter table public.lobby_members enable row level security;

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists (
        select 1 from public.friendships
        where status = 'accepted'
          and ((requester = a and addressee = b) or (requester = b and addressee = a))
    );
$$;

create or replace function public.lobby_alive(l public.lobbies)
returns boolean
language sql
stable
as $$
    select l.status <> 'closed' and l.last_seen_at > now() - interval '3 minutes';
$$;

-- Creates a lobby (the host's other lobbies are closed). Returns its id and join code.
create or replace function public.create_lobby(
    p_name text,
    p_mc_version text,
    p_loader text,
    p_pack_url text,
    p_pack_sha1 text,
    p_privacy text,
    p_max_players int,
    p_nick text
)
returns table (lobby_id uuid, code text)
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    new_code text;
    new_id uuid;
    i int;
begin
    if me is null then
        raise exception 'not signed in';
    end if;

    update public.lobbies set status = 'closed' where host = me and status <> 'closed';

    loop
        new_code := '';
        for i in 1..6 loop
            new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
        end loop;
        exit when not exists (select 1 from public.lobbies where lobbies.code = new_code);
    end loop;

    insert into public.lobbies (host, code, name, mc_version, loader, pack_url, pack_sha1, privacy, max_players)
    values (me, new_code, left(trim(p_name), 40), p_mc_version, p_loader, nullif(p_pack_url, ''),
            nullif(p_pack_sha1, ''), p_privacy, p_max_players)
    returning id into new_id;

    insert into public.lobby_members (lobby_id, user_id, nick, state) values (new_id, me, p_nick, 'joined');

    lobby_id := new_id;
    code := new_code;
    return next;
end;
$$;

-- Host: the server is up. Stores the public relay address and marks the lobby open.
create or replace function public.set_lobby_address(p_lobby uuid, p_address text)
returns void
language sql
security definer
set search_path = public
as $$
    update public.lobbies
    set address = nullif(trim(p_address), ''), status = 'open', last_seen_at = now()
    where id = p_lobby and host = auth.uid() and status <> 'closed';
$$;

create or replace function public.lobby_heartbeat(p_lobby uuid)
returns void
language sql
security definer
set search_path = public
as $$
    update public.lobbies set last_seen_at = now()
    where id = p_lobby and host = auth.uid() and status <> 'closed';
$$;

create or replace function public.close_lobby(p_lobby uuid)
returns void
language sql
security definer
set search_path = public
as $$
    update public.lobbies set status = 'closed' where id = p_lobby and host = auth.uid();
$$;

-- Host invites an accepted friend.
create or replace function public.invite_to_lobby(p_lobby uuid, p_user uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
begin
    if not exists (select 1 from public.lobbies where id = p_lobby and host = me and status <> 'closed') then
        return 'forbidden';
    end if;
    if not public.are_friends(me, p_user) then
        return 'not_friends';
    end if;
    -- The nick is chosen by the guest when joining; an invite row uses a placeholder.
    insert into public.lobby_members (lobby_id, user_id, nick, state)
    values (p_lobby, p_user, 'inv_' || substr(replace(p_user::text, '-', ''), 1, 12), 'invited')
    on conflict (lobby_id, user_id) do nothing;
    return 'invited';
end;
$$;

-- Join by code or by id. Result: 'ok', 'not_found', 'closed', 'forbidden', 'full', 'nick_taken', 'not_ready'.
-- On 'ok' the lobby row (with address and pack) is returned in the second column.
create or replace function public.join_lobby(p_code text, p_lobby uuid, p_nick text)
returns table (result text, lobby jsonb)
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    l public.lobbies%rowtype;
    mine public.lobby_members%rowtype;
    joined_count int;
begin
    if me is null then
        result := 'forbidden'; return next; return;
    end if;

    select * into l from public.lobbies
    where (p_lobby is not null and id = p_lobby) or (p_lobby is null and code = upper(trim(p_code)));
    if not found then
        result := 'not_found'; return next; return;
    end if;
    if not public.lobby_alive(l) then
        result := 'closed'; return next; return;
    end if;

    select * into mine from public.lobby_members where lobby_id = l.id and user_id = me;

    if l.host <> me and not found then
        -- By id (friends list): friends of the host only. By code: any signed-in user holding the code.
        -- Invite-only lobbies admit invited people only, code or not.
        if l.privacy = 'invite' then
            result := 'forbidden'; return next; return;
        end if;
        if p_lobby is not null and not public.are_friends(me, l.host) then
            result := 'forbidden'; return next; return;
        end if;
    end if;

    if l.address is null or l.status <> 'open' then
        result := 'not_ready'; return next; return;
    end if;

    select count(*) into joined_count from public.lobby_members where lobby_id = l.id and state = 'joined';
    if joined_count >= l.max_players and (mine.user_id is null or mine.state <> 'joined') then
        result := 'full'; return next; return;
    end if;

    if exists (select 1 from public.lobby_members
               where lobby_id = l.id and lower(nick) = lower(p_nick) and user_id <> me) then
        result := 'nick_taken'; return next; return;
    end if;

    insert into public.lobby_members (lobby_id, user_id, nick, state)
    values (l.id, me, p_nick, 'joined')
    on conflict (lobby_id, user_id) do update set nick = excluded.nick, state = 'joined';

    result := 'ok';
    lobby := jsonb_build_object(
        'id', l.id, 'name', l.name, 'mc_version', l.mc_version, 'loader', l.loader,
        'pack_url', l.pack_url, 'pack_sha1', l.pack_sha1, 'address', l.address,
        'max_players', l.max_players, 'host', l.host
    );
    return next;
end;
$$;

create or replace function public.leave_lobby(p_lobby uuid)
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.lobby_members where lobby_id = p_lobby and user_id = auth.uid();
$$;

-- Who may join: used by the host's launcher to build whitelist.json. Members only.
create or replace function public.lobby_roster(p_lobby uuid)
returns table (user_id uuid, nick text, state text)
language sql
security definer
stable
set search_path = public
as $$
    select m.user_id, m.nick, m.state
    from public.lobby_members m
    where m.lobby_id = p_lobby
      and m.state = 'joined'
      and exists (select 1 from public.lobby_members me
                  where me.lobby_id = p_lobby and me.user_id = auth.uid() and me.state = 'joined');
$$;

-- Lobbies the caller can see in Social: friends' lobbies open to friends, and invitations.
-- The address is not included; join_lobby returns it.
create or replace function public.visible_lobbies()
returns table (
    lobby_id uuid,
    name text,
    mc_version text,
    loader text,
    host_user uuid,
    host_tag text,
    host_name text,
    players int,
    max_players int,
    invited boolean,
    ready boolean
)
language sql
security definer
stable
set search_path = public
as $$
    select
        l.id, l.name, l.mc_version, l.loader, l.host, p.tag, p.display_name,
        (select count(*)::int from public.lobby_members m where m.lobby_id = l.id and m.state = 'joined'),
        l.max_players,
        exists (select 1 from public.lobby_members m
                where m.lobby_id = l.id and m.user_id = auth.uid() and m.state = 'invited'),
        (l.status = 'open' and l.address is not null)
    from public.lobbies l
    join public.profiles p on p.id = l.host
    where public.lobby_alive(l)
      and l.host <> auth.uid()
      and (
          (l.privacy = 'friends' and public.are_friends(auth.uid(), l.host))
          or exists (select 1 from public.lobby_members m
                     where m.lobby_id = l.id and m.user_id = auth.uid() and m.state = 'invited')
      );
$$;

revoke all on function public.are_friends(uuid, uuid) from public, anon, authenticated;
revoke all on function public.create_lobby(text, text, text, text, text, text, int, text) from public, anon;
revoke all on function public.set_lobby_address(uuid, text) from public, anon;
revoke all on function public.lobby_heartbeat(uuid) from public, anon;
revoke all on function public.close_lobby(uuid) from public, anon;
revoke all on function public.invite_to_lobby(uuid, uuid) from public, anon;
revoke all on function public.join_lobby(text, uuid, text) from public, anon;
revoke all on function public.leave_lobby(uuid) from public, anon;
revoke all on function public.lobby_roster(uuid) from public, anon;
revoke all on function public.visible_lobbies() from public, anon;
grant execute on function public.create_lobby(text, text, text, text, text, text, int, text) to authenticated;
grant execute on function public.set_lobby_address(uuid, text) to authenticated;
grant execute on function public.lobby_heartbeat(uuid) to authenticated;
grant execute on function public.close_lobby(uuid) to authenticated;
grant execute on function public.invite_to_lobby(uuid, uuid) to authenticated;
grant execute on function public.join_lobby(text, uuid, text) to authenticated;
grant execute on function public.leave_lobby(uuid) to authenticated;
grant execute on function public.lobby_roster(uuid) to authenticated;
grant execute on function public.visible_lobbies() to authenticated;


-- 9. Tunnel signaling ---------------------------------------------------------
-- Peer-to-peer play: the host's launcher and each guest's launcher learn each other's public UDP
-- endpoint (found with STUN) through short-lived signals, then punch through their NATs.
-- tunnel_key encrypts the tunnel; only joined members of the lobby can read it.

alter table public.lobbies
    add column if not exists tunnel_key text not null
    default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');

create table if not exists public.lobby_signals (
    id bigint generated always as identity primary key,
    lobby_id uuid not null references public.lobbies(id) on delete cascade,
    from_user uuid not null references auth.users(id) on delete cascade,
    to_user uuid not null references auth.users(id) on delete cascade,
    payload text not null check (char_length(payload) <= 400),
    created_at timestamptz not null default now()
);

create index if not exists lobby_signals_to_idx on public.lobby_signals (to_user, lobby_id, id);

alter table public.lobby_signals enable row level security;

create or replace function public.lobby_member_joined(p_lobby uuid, p_user uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists (select 1 from public.lobby_members
                   where lobby_id = p_lobby and user_id = p_user and state = 'joined');
$$;

-- Joined members only (host included).
create or replace function public.lobby_tunnel_key(p_lobby uuid)
returns text
language sql
security definer
stable
set search_path = public
as $$
    select l.tunnel_key from public.lobbies l
    where l.id = p_lobby and l.status <> 'closed'
      and public.lobby_member_joined(l.id, auth.uid());
$$;

-- Send a signal to another joined member of the same lobby.
create or replace function public.post_lobby_signal(p_lobby uuid, p_to uuid, p_payload text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
begin
    if me is null or not public.lobby_member_joined(p_lobby, me) or not public.lobby_member_joined(p_lobby, p_to) then
        raise exception 'forbidden';
    end if;
    delete from public.lobby_signals where created_at < now() - interval '10 minutes';
    insert into public.lobby_signals (lobby_id, from_user, to_user, payload)
    values (p_lobby, me, p_to, p_payload);
end;
$$;

-- Signals addressed to the caller with id > p_after and younger than 2 minutes, oldest first.
create or replace function public.fetch_lobby_signals(p_lobby uuid, p_after bigint default 0)
returns table (id bigint, from_user uuid, payload text)
language sql
security definer
stable
set search_path = public
as $$
    select s.id, s.from_user, s.payload
    from public.lobby_signals s
    where s.lobby_id = p_lobby and s.to_user = auth.uid() and s.id > p_after
      and s.created_at > now() - interval '2 minutes'
    order by s.id;
$$;

revoke all on function public.lobby_member_joined(uuid, uuid) from public, anon, authenticated;
revoke all on function public.lobby_tunnel_key(uuid) from public, anon;
revoke all on function public.post_lobby_signal(uuid, uuid, text) from public, anon;
revoke all on function public.fetch_lobby_signals(uuid, bigint) from public, anon;
grant execute on function public.lobby_tunnel_key(uuid) to authenticated;
grant execute on function public.post_lobby_signal(uuid, uuid, text) to authenticated;
grant execute on function public.fetch_lobby_signals(uuid, bigint) to authenticated;

-- 10. Mod list of a lobby ("modrinth:<version ids>") needs more room than a single URL.
alter table public.lobbies drop constraint if exists lobbies_pack_url_check;
alter table public.lobbies add constraint lobbies_pack_url_check check (char_length(pack_url) <= 20000);

-- 11. Lobby room --------------------------------------------------------------
-- Before the host starts the Minecraft server, a lobby is a room: host and friends
-- gather and agree on the shared content (mods, shaders, resource packs). The host
-- then calls set_lobby_address, which locks the content list and flips the lobby
-- to 'open'. Same model as section 8-9: RLS on, no policies, everything through
-- security definer functions.

alter table public.lobbies add column if not exists edit_policy text not null default 'host'
    check (edit_policy in ('host', 'friends', 'all'));
alter table public.lobbies add column if not exists sync_shaders boolean not null default false;
alter table public.lobbies add column if not exists sync_resourcepacks boolean not null default true;

alter table public.lobby_members add column if not exists can_edit boolean not null default false;

create table if not exists public.lobby_items (
    id uuid primary key default gen_random_uuid(),
    lobby_id uuid not null references public.lobbies(id) on delete cascade,
    kind text not null check (kind in ('mod', 'shader', 'resourcepack')),
    project_id text check (char_length(project_id) <= 32),
    version_id text not null check (version_id ~ '^[A-Za-z0-9]{1,16}$'),
    title text not null check (char_length(title) between 1 and 80),
    added_by uuid references auth.users(id) on delete set null,
    added_nick text,
    created_at timestamptz not null default now(),
    unique (lobby_id, version_id)
);

create index if not exists lobby_items_lobby_idx on public.lobby_items (lobby_id);

alter table public.lobby_items enable row level security;

-- Internal helper (like are_friends): is uid allowed to edit the content list of l.
create or replace function public.lobby_may_edit(l public.lobbies, uid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select l.host = uid or exists (
        select 1 from public.lobby_members m
        where m.lobby_id = l.id and m.user_id = uid and m.state = 'joined'
          and (l.edit_policy = 'all' or m.can_edit or (l.edit_policy = 'friends' and public.are_friends(uid, l.host)))
    );
$$;

-- Join by code or by id. Result: 'ok', 'not_found', 'closed', 'forbidden', 'full', 'nick_taken'.
-- Joining a room that hasn't started its server yet is allowed; only closed/dead lobbies are rejected.
-- On 'ok' the lobby row is returned in the second column; 'address' is included only once the
-- server is up (status = 'open').
create or replace function public.join_lobby(p_code text, p_lobby uuid, p_nick text)
returns table (result text, lobby jsonb)
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    l public.lobbies%rowtype;
    mine public.lobby_members%rowtype;
    joined_count int;
begin
    if me is null then
        result := 'forbidden'; return next; return;
    end if;

    select * into l from public.lobbies
    where (p_lobby is not null and id = p_lobby) or (p_lobby is null and code = upper(trim(p_code)));
    if not found then
        result := 'not_found'; return next; return;
    end if;
    if not public.lobby_alive(l) then
        result := 'closed'; return next; return;
    end if;

    select * into mine from public.lobby_members where lobby_id = l.id and user_id = me;

    if l.host <> me and not found then
        -- By id (friends list): friends of the host only. By code: any signed-in user holding the code.
        -- Invite-only lobbies admit invited people only, code or not.
        if l.privacy = 'invite' then
            result := 'forbidden'; return next; return;
        end if;
        if p_lobby is not null and not public.are_friends(me, l.host) then
            result := 'forbidden'; return next; return;
        end if;
    end if;

    select count(*) into joined_count from public.lobby_members where lobby_id = l.id and state = 'joined';
    if joined_count >= l.max_players and (mine.user_id is null or mine.state <> 'joined') then
        result := 'full'; return next; return;
    end if;

    if exists (select 1 from public.lobby_members
               where lobby_id = l.id and lower(nick) = lower(p_nick) and user_id <> me) then
        result := 'nick_taken'; return next; return;
    end if;

    insert into public.lobby_members (lobby_id, user_id, nick, state)
    values (l.id, me, p_nick, 'joined')
    on conflict (lobby_id, user_id) do update set nick = excluded.nick, state = 'joined';

    result := 'ok';
    lobby := jsonb_build_object(
        'id', l.id, 'name', l.name, 'mc_version', l.mc_version, 'loader', l.loader,
        'pack_url', l.pack_url, 'pack_sha1', l.pack_sha1,
        'address', case when l.status = 'open' then l.address else null end,
        'max_players', l.max_players, 'host', l.host,
        'status', l.status, 'edit_policy', l.edit_policy,
        'sync_shaders', l.sync_shaders, 'sync_resourcepacks', l.sync_resourcepacks,
        'can_edit', public.lobby_may_edit(l, me)
    );
    return next;
end;
$$;

drop function if exists public.lobby_roster(uuid);

-- Who may join: used by the host's launcher to build whitelist.json. Members only.
create function public.lobby_roster(p_lobby uuid)
returns table (user_id uuid, nick text, state text, can_edit boolean)
language sql
security definer
stable
set search_path = public
as $$
    select m.user_id, m.nick, m.state, public.lobby_may_edit(l, m.user_id)
    from public.lobby_members m
    join public.lobbies l on l.id = m.lobby_id
    where m.lobby_id = p_lobby
      and m.state = 'joined'
      and exists (select 1 from public.lobby_members me
                  where me.lobby_id = p_lobby and me.user_id = auth.uid() and me.state = 'joined');
$$;

drop function if exists public.visible_lobbies();

-- Lobbies the caller can see in Social: friends' lobbies open to friends, and invitations.
-- The address is not included; join_lobby / lobby_info return it. 'ready' now covers both the
-- room (status 'starting') and the running server (status 'open'); 'running' is the server only.
create function public.visible_lobbies()
returns table (
    lobby_id uuid,
    name text,
    mc_version text,
    loader text,
    host_user uuid,
    host_tag text,
    host_name text,
    players int,
    max_players int,
    invited boolean,
    ready boolean,
    running boolean
)
language sql
security definer
stable
set search_path = public
as $$
    select
        l.id, l.name, l.mc_version, l.loader, l.host, p.tag, p.display_name,
        (select count(*)::int from public.lobby_members m where m.lobby_id = l.id and m.state = 'joined'),
        l.max_players,
        exists (select 1 from public.lobby_members m
                where m.lobby_id = l.id and m.user_id = auth.uid() and m.state = 'invited'),
        (l.status in ('starting', 'open')),
        (l.status = 'open' and l.address is not null)
    from public.lobbies l
    join public.profiles p on p.id = l.host
    where public.lobby_alive(l)
      and l.host <> auth.uid()
      and (
          (l.privacy = 'friends' and public.are_friends(auth.uid(), l.host))
          or exists (select 1 from public.lobby_members m
                     where m.lobby_id = l.id and m.user_id = auth.uid() and m.state = 'invited')
      );
$$;

-- Full snapshot of a lobby for a joined member (host included). Returns null when the
-- caller may not see it or the lobby is not alive. The address is included only once open.
create or replace function public.lobby_info(p_lobby uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
    me uuid := auth.uid();
    l public.lobbies%rowtype;
begin
    if me is null then
        return null;
    end if;

    select * into l from public.lobbies where id = p_lobby;
    if not found or not public.lobby_alive(l) then
        return null;
    end if;

    if l.host <> me and not exists (
        select 1 from public.lobby_members where lobby_id = l.id and user_id = me and state = 'joined'
    ) then
        return null;
    end if;

    return jsonb_build_object(
        'id', l.id, 'name', l.name, 'mc_version', l.mc_version, 'loader', l.loader,
        'host', l.host, 'status', l.status, 'max_players', l.max_players,
        'edit_policy', l.edit_policy, 'sync_shaders', l.sync_shaders,
        'sync_resourcepacks', l.sync_resourcepacks,
        'can_edit', public.lobby_may_edit(l, me),
        'address', case when l.status = 'open' then l.address else null end
    );
end;
$$;

-- Host: content-sync rules for the room. Blocked once the lobby is closed.
create or replace function public.set_lobby_settings(
    p_lobby uuid,
    p_edit_policy text,
    p_sync_shaders boolean,
    p_sync_resourcepacks boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_edit_policy not in ('host', 'friends', 'all') then
        raise exception 'invalid edit policy';
    end if;

    update public.lobbies
    set edit_policy = p_edit_policy,
        sync_shaders = p_sync_shaders,
        sync_resourcepacks = p_sync_resourcepacks
    where id = p_lobby and host = auth.uid() and status <> 'closed';
end;
$$;

-- Host: grant or revoke a specific member's edit right (used with edit_policy = 'host').
create or replace function public.set_member_can_edit(p_lobby uuid, p_user uuid, p_can boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
begin
    if not exists (select 1 from public.lobbies where id = p_lobby and host = me and status <> 'closed') then
        return;
    end if;
    if p_user = me then
        return;
    end if;
    update public.lobby_members set can_edit = p_can
    where lobby_id = p_lobby and user_id = p_user;
end;
$$;

-- Content list for a lobby. Members only.
create or replace function public.lobby_items_list(p_lobby uuid)
returns table (
    id uuid, kind text, project_id text, version_id text, title text,
    added_by uuid, added_nick text, created_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
    select i.id, i.kind, i.project_id, i.version_id, i.title, i.added_by, i.added_nick, i.created_at
    from public.lobby_items i
    where i.lobby_id = p_lobby
      and exists (select 1 from public.lobby_members m
                  where m.lobby_id = p_lobby and m.user_id = auth.uid() and m.state = 'joined')
    order by i.created_at;
$$;

-- Add one item to the room's content list. Result: 'ok', 'forbidden', 'locked', 'limit',
-- 'duplicate', 'invalid'. Content can only be edited while the lobby is 'starting'.
create or replace function public.add_lobby_item(
    p_lobby uuid,
    p_kind text,
    p_project text,
    p_version text,
    p_title text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    l public.lobbies%rowtype;
    my_nick text;
    item_count int;
begin
    select * into l from public.lobbies where id = p_lobby;
    if not found or not public.lobby_alive(l) then
        return 'invalid';
    end if;
    if l.status <> 'starting' then
        return 'locked';
    end if;
    if p_kind not in ('mod', 'shader', 'resourcepack') then
        return 'invalid';
    end if;
    if p_version !~ '^[A-Za-z0-9]{1,16}$'
       or char_length(coalesce(p_project, '')) > 32
       or char_length(trim(coalesce(p_title, ''))) not between 1 and 80 then
        return 'invalid';
    end if;

    select nick into my_nick from public.lobby_members
    where lobby_id = p_lobby and user_id = me and state = 'joined';
    if my_nick is null or not public.lobby_may_edit(l, me) then
        return 'forbidden';
    end if;

    if exists (select 1 from public.lobby_items where lobby_id = p_lobby and version_id = p_version) then
        return 'duplicate';
    end if;

    select count(*) into item_count from public.lobby_items where lobby_id = p_lobby;
    if item_count >= 300 then
        return 'limit';
    end if;

    insert into public.lobby_items (lobby_id, kind, project_id, version_id, title, added_by, added_nick)
    values (p_lobby, p_kind, nullif(p_project, ''), p_version, left(trim(p_title), 80), me, my_nick);

    return 'ok';
end;
$$;

-- Remove one item. Result: 'ok', 'forbidden', 'locked', 'not_found'. The host may always
-- remove; anyone else needs to still hold edit rights and be the one who added it.
create or replace function public.remove_lobby_item(p_lobby uuid, p_item uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    l public.lobbies%rowtype;
    it public.lobby_items%rowtype;
begin
    select * into l from public.lobbies where id = p_lobby;
    if not found or not public.lobby_alive(l) then
        return 'not_found';
    end if;
    if l.status <> 'starting' then
        return 'locked';
    end if;

    select * into it from public.lobby_items where id = p_item and lobby_id = p_lobby;
    if not found then
        return 'not_found';
    end if;

    if l.host <> me and not (it.added_by = me and public.lobby_may_edit(l, me)) then
        return 'forbidden';
    end if;

    delete from public.lobby_items where id = p_item;
    return 'ok';
end;
$$;

-- Host: stop the server and reopen the content list for editing.
create or replace function public.reopen_lobby(p_lobby uuid)
returns void
language sql
security definer
set search_path = public
as $$
    update public.lobbies
    set status = 'starting', address = null, last_seen_at = now()
    where id = p_lobby and host = auth.uid() and status = 'open';
$$;

revoke all on function public.lobby_may_edit(public.lobbies, uuid) from public, anon, authenticated;
revoke all on function public.join_lobby(text, uuid, text) from public, anon;
revoke all on function public.lobby_roster(uuid) from public, anon;
revoke all on function public.visible_lobbies() from public, anon;
revoke all on function public.lobby_info(uuid) from public, anon;
revoke all on function public.set_lobby_settings(uuid, text, boolean, boolean) from public, anon;
revoke all on function public.set_member_can_edit(uuid, uuid, boolean) from public, anon;
revoke all on function public.lobby_items_list(uuid) from public, anon;
revoke all on function public.add_lobby_item(uuid, text, text, text, text) from public, anon;
revoke all on function public.remove_lobby_item(uuid, uuid) from public, anon;
revoke all on function public.reopen_lobby(uuid) from public, anon;
grant execute on function public.join_lobby(text, uuid, text) to authenticated;
grant execute on function public.lobby_roster(uuid) to authenticated;
grant execute on function public.visible_lobbies() to authenticated;
grant execute on function public.lobby_info(uuid) to authenticated;
grant execute on function public.set_lobby_settings(uuid, text, boolean, boolean) to authenticated;
grant execute on function public.set_member_can_edit(uuid, uuid, boolean) to authenticated;
grant execute on function public.lobby_items_list(uuid) to authenticated;
grant execute on function public.add_lobby_item(uuid, text, text, text, text) to authenticated;
grant execute on function public.remove_lobby_item(uuid, uuid) to authenticated;
grant execute on function public.reopen_lobby(uuid) to authenticated;
