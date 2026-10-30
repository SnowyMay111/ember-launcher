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
