create or replace function public.merge_sync_payload(
  current_payload jsonb,
  incoming_payload jsonb
) returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  entry jsonb;
  previous jsonb;
  entry_key text;
  items_by_id jsonb := '{}'::jsonb;
  attempts_by_id jsonb := '{}'::jsonb;
  sessions_by_key jsonb := '{}'::jsonb;
  grammar_progress_by_topic jsonb := '{}'::jsonb;
  grammar_attempts_by_id jsonb := '{}'::jsonb;
  merged_items jsonb;
  merged_attempts jsonb;
  merged_sessions jsonb;
  merged_grammar_progress jsonb;
  merged_grammar_attempts jsonb;
  previous_rank integer;
  entry_rank integer;
begin
  for entry in select value from jsonb_array_elements(
    coalesce(current_payload -> 'items', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'items', '[]'::jsonb)
  ) loop
    entry_key := entry ->> 'id';
    previous := items_by_id -> entry_key;
    if previous is null
      or coalesce(entry ->> 'updatedAt', '') > coalesce(previous ->> 'updatedAt', '')
      or (coalesce(entry ->> 'updatedAt', '') = coalesce(previous ->> 'updatedAt', '')
          and entry::text > previous::text) then
      items_by_id := jsonb_set(items_by_id, array[entry_key], entry, true);
    end if;
  end loop;

  for entry in select value from jsonb_array_elements(
    coalesce(current_payload -> 'attempts', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'attempts', '[]'::jsonb)
  ) loop
    entry_key := entry ->> 'id';
    if attempts_by_id -> entry_key is null then
      attempts_by_id := jsonb_set(attempts_by_id, array[entry_key], entry, true);
    end if;
  end loop;

  for entry in select value from jsonb_array_elements(
    coalesce(current_payload -> 'sessions', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'sessions', '[]'::jsonb)
  ) loop
    entry_key := case
      when entry ->> 'slot' is null then 'extra:' || (entry ->> 'id')
      else 'required:' || (entry ->> 'localDate') || ':' || (entry ->> 'slot')
    end;
    previous := sessions_by_key -> entry_key;
    entry_rank := case entry ->> 'status'
      when 'completed' then 2 when 'in_progress' then 1 else 0 end;
    previous_rank := case previous ->> 'status'
      when 'completed' then 2 when 'in_progress' then 1 else 0 end;
    if previous is null
      or entry_rank > previous_rank
      or (entry_rank = previous_rank and
          coalesce((entry ->> 'answeredCount')::integer, 0) >
          coalesce((previous ->> 'answeredCount')::integer, 0))
      or (entry_rank = previous_rank and
          coalesce((entry ->> 'answeredCount')::integer, 0) =
          coalesce((previous ->> 'answeredCount')::integer, 0) and
          (coalesce(entry ->> 'updatedAt', '') > coalesce(previous ->> 'updatedAt', '')
           or (coalesce(entry ->> 'updatedAt', '') = coalesce(previous ->> 'updatedAt', '')
               and entry::text > previous::text))) then
      sessions_by_key := jsonb_set(sessions_by_key, array[entry_key], entry, true);
    end if;
  end loop;

  for entry in select value from jsonb_array_elements(
    coalesce(current_payload -> 'grammarProgress', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'grammarProgress', '[]'::jsonb)
  ) loop
    entry_key := entry ->> 'topicId';
    previous := grammar_progress_by_topic -> entry_key;
    if previous is null
      or coalesce(entry ->> 'updatedAt', '') > coalesce(previous ->> 'updatedAt', '')
      or (coalesce(entry ->> 'updatedAt', '') = coalesce(previous ->> 'updatedAt', '')
          and entry::text > previous::text) then
      grammar_progress_by_topic := jsonb_set(
        grammar_progress_by_topic, array[entry_key], entry, true
      );
    end if;
  end loop;

  for entry in select value from jsonb_array_elements(
    coalesce(current_payload -> 'grammarAttempts', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'grammarAttempts', '[]'::jsonb)
  ) loop
    entry_key := entry ->> 'id';
    if grammar_attempts_by_id -> entry_key is null then
      grammar_attempts_by_id := jsonb_set(
        grammar_attempts_by_id, array[entry_key], entry, true
      );
    end if;
  end loop;

  select coalesce(jsonb_agg(value order by key), '[]'::jsonb)
    into merged_items from jsonb_each(items_by_id);
  select coalesce(jsonb_agg(value order by key), '[]'::jsonb)
    into merged_attempts from jsonb_each(attempts_by_id);
  select coalesce(jsonb_agg(value order by key), '[]'::jsonb)
    into merged_sessions from jsonb_each(sessions_by_key);
  select coalesce(jsonb_agg(value order by key), '[]'::jsonb)
    into merged_grammar_progress from jsonb_each(grammar_progress_by_topic);
  select coalesce(jsonb_agg(value order by key), '[]'::jsonb)
    into merged_grammar_attempts from jsonb_each(grammar_attempts_by_id);

  return jsonb_build_object(
    'version', 2,
    'items', merged_items,
    'attempts', merged_attempts,
    'sessions', merged_sessions,
    'grammarProgress', merged_grammar_progress,
    'grammarAttempts', merged_grammar_attempts
  );
end;
$$;

create or replace function public.merge_sync_profile(
  p_nickname text,
  p_payload jsonb
) returns table(payload jsonb, revision bigint, updated_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_nickname !~ '^[a-z0-9_-]{3,24}$' then
    raise exception 'invalid nickname';
  end if;
  if p_payload ->> 'version' not in ('1', '2') then
    raise exception 'unsupported payload version';
  end if;

  return query
  insert into public.sync_profiles as profile (
    nickname, payload, revision, updated_at
  ) values (
    p_nickname, public.merge_sync_payload('{}'::jsonb, p_payload), 1, now()
  )
  on conflict (nickname) do update set
    payload = public.merge_sync_payload(profile.payload, excluded.payload),
    revision = profile.revision + 1,
    updated_at = now()
  returning profile.payload, profile.revision, profile.updated_at;
end;
$$;

revoke all on function public.merge_sync_payload(jsonb, jsonb) from public;
revoke all on function public.merge_sync_profile(text, jsonb) from public;
grant execute on function public.merge_sync_profile(text, jsonb) to service_role;
