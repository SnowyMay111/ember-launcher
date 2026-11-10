-- 12. Hardening -----------------------------------------------------------------
-- Safe to run more than once. Dead lobbies are deleted, tunnel signals and join-by-code attempts are rate
-- limited, profiles are for signed-in users only, and the Supabase advisor findings are closed
-- (search_path, functions open to anon, auth.uid() evaluated per row, foreign keys without an index).

-- 12.1 Profiles: signed-in users only; id, created_at and updated_at cannot be written by the owner.
drop policy if exists "profiles_select_own_or_public" on public.profiles;
create policy "profiles_select_own_or_public"
    on public.profiles
    for select
    to authenticated
    using (id = (select auth.uid()) or profile_visibility = 'public');

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
    on public.profiles
    for insert
    to authenticated
    with check (id = (select auth.uid()));

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
    on public.profiles
    for update
    to authenticated
    using (id = (select auth.uid()))
    with check (id = (select auth.uid()));

-- The launcher only reads a profile and patches it; the row itself is made by handle_new_user.
revoke all on public.profiles from anon;
revoke insert, update, delete, truncate, references, trigger on public.profiles from authenticated;
grant update (tag, display_name, bio, avatar_name, show_online_status, friend_requests, profile_visibility,
              show_stats, playtime_minutes, instances_count, mods_count, favorite_pack)
    on public.profiles to authenticated;

alter table public.profiles drop constraint if exists profiles_favorite_pack_check;
alter table public.profiles add constraint profiles_favorite_pack_check check (char_length(favorite_pack) <= 120);

-- Every other table is reached through security definer functions only (RLS on, no policies).
revoke all on public.friendships, public.presence, public.lobbies, public.lobby_members,
              public.lobby_signals, public.lobby_items
    from anon, authenticated;

-- 12.2 Functions: a fixed search_path everywhere, nothing callable by anon that does not need to be.
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace function public.lobby_alive(l public.lobbies)
returns boolean
language sql
stable
set search_path = public
as $$
    select l.status <> 'closed' and l.last_seen_at > now() - interval '3 minutes';
$$;

-- A trigger fires without an EXECUTE check; the grant to the auth service is a belt for the braces.
revoke all on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;
revoke all on function public.lobby_alive(public.lobbies) from public, anon, authenticated;
revoke all on function public.lobby_roster_tags(uuid) from public, anon;
grant execute on function public.lobby_roster_tags(uuid) to authenticated;

-- 12.3 Indexes: the foreign keys that had none, and the columns the cleanups and limits filter on.
create index if not exists lobby_items_added_by_idx on public.lobby_items (added_by);
create index if not exists lobby_signals_from_idx on public.lobby_signals (from_user, created_at);
create index if not exists lobby_signals_lobby_idx on public.lobby_signals (lobby_id);
create index if not exists lobby_signals_created_idx on public.lobby_signals (created_at);
create index if not exists lobbies_last_seen_idx on public.lobbies (last_seen_at);

-- 12.4 Wrong join codes, for the limit in join_lobby.
create table if not exists public.lobby_join_attempts (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);
create index if not exists lobby_join_attempts_user_idx on public.lobby_join_attempts (user_id, created_at);
alter table public.lobby_join_attempts enable row level security;
revoke all on public.lobby_join_attempts from anon, authenticated;

-- 12.5 Deletes what nobody can use any more: lobbies closed over an hour ago or silent for a day (their members,
-- items and signals go with them by cascade) and old join attempts. create_lobby calls it, so the tables stay small.
create or replace function public.purge_dead_lobbies()
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.lobbies
    where (status = 'closed' and last_seen_at < now() - interval '1 hour')
       or last_seen_at < now() - interval '1 day';
    delete from public.lobby_join_attempts where created_at < now() - interval '1 day';
$$;
revoke all on function public.purge_dead_lobbies() from public, anon, authenticated;

-- Creates a lobby (the host's other lobbies are closed). Returns its id and join code.
-- The code comes from gen_random_uuid(), not random(): six of its random bytes, five bits each.
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
    bytes text;
    i int;
begin
    if me is null then
        raise exception 'not signed in';
    end if;

    perform public.purge_dead_lobbies();
    update public.lobbies set status = 'closed' where host = me and status <> 'closed';

    loop
        new_code := '';
        bytes := replace(gen_random_uuid()::text, '-', '');
        for i in 1..6 loop
            new_code := new_code || substr(alphabet, 1 + (('x' || substr(bytes, i * 2 - 1, 2))::bit(8)::int % 32), 1);
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

-- 12.6 Send a signal to another joined member of the same lobby: at most 60 a minute from one sender.
-- A handshake is one signal each way, so the limit only stops a flood.
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
    if (select count(*) from public.lobby_signals
        where from_user = me and created_at > now() - interval '1 minute') >= 60 then
        raise exception 'rate limited';
    end if;
    insert into public.lobby_signals (lobby_id, from_user, to_user, payload)
    values (p_lobby, me, p_to, p_payload);
end;
$$;

-- 12.7 join_lobby as in section 11, plus a limit on guessing codes: ten wrong codes a minute, then
-- 'rate_limited' until the minute has passed. Joining by id (friends list) is not limited.
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

    if p_lobby is null and (select count(*) from public.lobby_join_attempts
                            where user_id = me and created_at > now() - interval '1 minute') >= 10 then
        result := 'rate_limited'; return next; return;
    end if;

    select * into l from public.lobbies
    where (p_lobby is not null and id = p_lobby) or (p_lobby is null and code = upper(trim(p_code)));
    if not found then
        if p_lobby is null then
            delete from public.lobby_join_attempts where user_id = me and created_at < now() - interval '10 minutes';
            insert into public.lobby_join_attempts (user_id) values (me);
        end if;
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

-- 12.8 Host: stop the server and reopen the content list for editing. The tunnel key is replaced, so whoever
-- left the lobby cannot use the old one; host and guests fetch the key again each time a tunnel starts.
create or replace function public.reopen_lobby(p_lobby uuid)
returns void
language sql
security definer
set search_path = public
as $$
    update public.lobbies
    set status = 'starting', address = null, last_seen_at = now(),
        tunnel_key = replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
    where id = p_lobby and host = auth.uid() and status = 'open';
$$;

revoke all on function public.create_lobby(text, text, text, text, text, text, int, text) from public, anon;
revoke all on function public.post_lobby_signal(uuid, uuid, text) from public, anon;
revoke all on function public.join_lobby(text, uuid, text) from public, anon;
revoke all on function public.reopen_lobby(uuid) from public, anon;
grant execute on function public.create_lobby(text, text, text, text, text, text, int, text) to authenticated;
grant execute on function public.post_lobby_signal(uuid, uuid, text) to authenticated;
grant execute on function public.join_lobby(text, uuid, text) to authenticated;
grant execute on function public.reopen_lobby(uuid) to authenticated;
