-- Manual maintenance query: remove invalid ghost meetings.
delete from public.meetings
where current_members <= 0;