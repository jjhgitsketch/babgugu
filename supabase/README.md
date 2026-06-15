# Supabase schema

This folder contains the BabGuGu Supabase database and storage setup.

## Automated deployment

GitHub Actions runs the files in `supabase/migrations` with `supabase db push`.
Only safe, idempotent schema changes belong in `migrations`.

Required GitHub repository secrets:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID`
- `SUPABASE_DB_PASSWORD`

Edge function runtime secrets such as `RESEND_API_KEY`, `MAIL_FROM`, and `SUPABASE_SERVICE_ROLE_KEY` should be configured in Supabase, not committed to GitHub.

## Manual SQL

Files in `supabase/manual` are not for automatic deployment.
Run them manually in the Supabase SQL Editor only when needed.

- `reset_app_tables.sql`: deletes app tables and data.
- `purge_invalid_meetings.sql`: removes meetings with `current_members <= 0`.