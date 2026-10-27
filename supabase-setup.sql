-- KJ Silva's Nikah RSVP. Safe to run once in the existing KJ Dinner Poll project.
-- Creates only Nikah-specific objects; it does not alter or read the dinner-poll tables.
-- Do not add organizer emails to this public file or to the GitHub repository.

create table if not exists public.kj_nikah_rsvp_responses (
  voter_id uuid primary key,
  poll_id text not null default 'kj-nikah-rsvp-2026-10-29',
  respondent_name text not null,
  phone_number text not null default '',
  response_choice text not null,
  submitted_at timestamptz not null default now(),
  constraint kj_nikah_rsvp_poll_id check (poll_id = 'kj-nikah-rsvp-2026-10-29'),
  constraint kj_nikah_rsvp_name_length check (char_length(btrim(respondent_name)) between 1 and 80),
  constraint kj_nikah_rsvp_phone_length check (char_length(phone_number) <= 40),
  constraint kj_nikah_rsvp_allowed_choice check (
    response_choice in ('Yes, insha’Allah', 'No, sorry wish I could', 'Not sure, insha’Allah')
  )
);

create index if not exists kj_nikah_rsvp_responses_submitted_idx
  on public.kj_nikah_rsvp_responses (submitted_at desc);

alter table public.kj_nikah_rsvp_responses enable row level security;
revoke all privileges on table public.kj_nikah_rsvp_responses from public, anon, authenticated;

-- Private email allowlist. Add KJ only after his correct sign-in address is confirmed.
create table if not exists public.kj_nikah_rsvp_organizers (
  email text primary key check (email = lower(email)),
  added_at timestamptz not null default now()
);
alter table public.kj_nikah_rsvp_organizers enable row level security;
revoke all privileges on table public.kj_nikah_rsvp_organizers from public, anon, authenticated;

create or replace function public.is_kj_nikah_rsvp_organizer()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.kj_nikah_rsvp_organizers o
    where o.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all privileges on function public.is_kj_nikah_rsvp_organizer() from public, anon, authenticated;
grant execute on function public.is_kj_nikah_rsvp_organizer() to authenticated;

-- Public result: aggregate counts only; no names, phone numbers, or individual choices.
create or replace function public.get_kj_nikah_rsvp_totals()
returns table (response_choice text, response_count bigint)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select r.response_choice, count(*)::bigint
  from public.kj_nikah_rsvp_responses r
  where r.poll_id = 'kj-nikah-rsvp-2026-10-29'
  group by r.response_choice;
$$;
revoke all privileges on function public.get_kj_nikah_rsvp_totals() from public, anon, authenticated;
grant execute on function public.get_kj_nikah_rsvp_totals() to anon, authenticated;

-- Public submission/update goes through a bounded RPC; direct table access stays revoked.
create or replace function public.submit_kj_nikah_rsvp(
  p_voter_id uuid,
  p_respondent_name text,
  p_phone_number text,
  p_response_choice text
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if p_voter_id is null then
    raise exception 'A response id is required';
  end if;
  if char_length(btrim(coalesce(p_respondent_name, ''))) not between 1 and 80 then
    raise exception 'A name is required (up to 80 characters)';
  end if;
  if char_length(coalesce(p_phone_number, '')) > 40 then
    raise exception 'Phone number is too long';
  end if;
  if coalesce(p_response_choice, '') not in
    ('Yes, insha’Allah', 'No, sorry wish I could', 'Not sure, insha’Allah') then
    raise exception 'Choose one valid RSVP response';
  end if;

  insert into public.kj_nikah_rsvp_responses (
    voter_id, poll_id, respondent_name, phone_number, response_choice, submitted_at
  ) values (
    p_voter_id, 'kj-nikah-rsvp-2026-10-29', btrim(p_respondent_name),
    coalesce(p_phone_number, ''), p_response_choice, now()
  )
  on conflict (voter_id) do update set
    respondent_name = excluded.respondent_name,
    phone_number = excluded.phone_number,
    response_choice = excluded.response_choice,
    submitted_at = now();
end;
$$;
revoke all privileges on function public.submit_kj_nikah_rsvp(uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.submit_kj_nikah_rsvp(uuid, text, text, text)
  to anon, authenticated;

-- Individual answers are returned only to authenticated allowlisted organizers.
create or replace function public.list_kj_nikah_rsvp_responses()
returns table (
  respondent_name text,
  phone_number text,
  response_choice text,
  submitted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not public.is_kj_nikah_rsvp_organizer() then
    raise exception 'Organizer access required' using errcode = '42501';
  end if;
  return query
    select r.respondent_name, r.phone_number, r.response_choice, r.submitted_at
    from public.kj_nikah_rsvp_responses r
    where r.poll_id = 'kj-nikah-rsvp-2026-10-29'
    order by r.submitted_at desc;
end;
$$;
revoke all privileges on function public.list_kj_nikah_rsvp_responses() from public, anon, authenticated;
grant execute on function public.list_kj_nikah_rsvp_responses() to authenticated;
