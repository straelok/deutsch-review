create or replace function public.merge_sync_payload(
  current_payload jsonb,
  incoming_payload jsonb
) returns jsonb
language sql
immutable
set search_path = public
as $$
with
item_entries as (
  select
    value as entry,
    value ->> 'id' as entry_key
  from jsonb_array_elements(
    coalesce(current_payload -> 'items', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'items', '[]'::jsonb)
  )
),
merged_items as (
  select coalesce(jsonb_agg(entry order by entry_key), '[]'::jsonb) as value
  from (
    select distinct on (entry_key) entry_key, entry
    from item_entries
    order by
      entry_key,
      coalesce(entry ->> 'updatedAt', '') desc,
      entry::text desc
  ) selected
),
attempt_entries as (
  select
    value as entry,
    value ->> 'id' as entry_key,
    ordinal
  from jsonb_array_elements(
    coalesce(current_payload -> 'attempts', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'attempts', '[]'::jsonb)
  ) with ordinality as source(value, ordinal)
),
merged_attempts as (
  select coalesce(jsonb_agg(entry order by entry_key), '[]'::jsonb) as value
  from (
    select distinct on (entry_key) entry_key, entry
    from attempt_entries
    order by entry_key, ordinal
  ) selected
),
session_entries as (
  select
    value as entry,
    case
      when value ->> 'slot' is null then 'extra:' || (value ->> 'id')
      else
        'required:' || (value ->> 'localDate') || ':' ||
        (value ->> 'slot')
    end as entry_key
  from jsonb_array_elements(
    coalesce(current_payload -> 'sessions', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'sessions', '[]'::jsonb)
  )
),
merged_sessions as (
  select coalesce(jsonb_agg(entry order by entry_key), '[]'::jsonb) as value
  from (
    select distinct on (entry_key) entry_key, entry
    from session_entries
    order by
      entry_key,
      case when entry ->> 'localDate' = 'persistent'
        then coalesce(entry ->> 'updatedAt', '')
        else ''
      end desc,
      case when entry ->> 'localDate' <> 'persistent'
        then case entry ->> 'status'
          when 'completed' then 2
          when 'in_progress' then 1
          else 0
        end
        else 0
      end desc,
      case when entry ->> 'localDate' <> 'persistent'
        then coalesce((entry ->> 'answeredCount')::integer, 0)
        else 0
      end desc,
      case when entry ->> 'localDate' <> 'persistent'
        then coalesce(entry ->> 'updatedAt', '')
        else ''
      end desc,
      entry::text desc
  ) selected
),
grammar_progress_entries as (
  select
    value as entry,
    value ->> 'topicId' as entry_key
  from jsonb_array_elements(
    coalesce(current_payload -> 'grammarProgress', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'grammarProgress', '[]'::jsonb)
  )
),
merged_grammar_progress as (
  select coalesce(jsonb_agg(entry order by entry_key), '[]'::jsonb) as value
  from (
    select distinct on (entry_key) entry_key, entry
    from grammar_progress_entries
    order by
      entry_key,
      coalesce(entry ->> 'updatedAt', '') desc,
      entry::text desc
  ) selected
),
grammar_attempt_entries as (
  select
    value as entry,
    value ->> 'id' as entry_key,
    ordinal
  from jsonb_array_elements(
    coalesce(current_payload -> 'grammarAttempts', '[]'::jsonb) ||
    coalesce(incoming_payload -> 'grammarAttempts', '[]'::jsonb)
  ) with ordinality as source(value, ordinal)
),
merged_grammar_attempts as (
  select coalesce(jsonb_agg(entry order by entry_key), '[]'::jsonb) as value
  from (
    select distinct on (entry_key) entry_key, entry
    from grammar_attempt_entries
    order by entry_key, ordinal
  ) selected
)
select jsonb_build_object(
  'version', 3,
  'items', merged_items.value,
  'attempts', merged_attempts.value,
  'sessions', merged_sessions.value,
  'grammarProgress', merged_grammar_progress.value,
  'grammarAttempts', merged_grammar_attempts.value
)
from
  merged_items,
  merged_attempts,
  merged_sessions,
  merged_grammar_progress,
  merged_grammar_attempts;
$$;

revoke all on function public.merge_sync_payload(jsonb, jsonb) from public;
