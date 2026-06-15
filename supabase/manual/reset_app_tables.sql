-- Manual reset script for BabGuGu app tables.
-- WARNING: This deletes app data. Do not run from automated deployment.

drop table if exists public.notifications cascade;
drop table if exists public.meal_history cascade;
drop table if exists public.solo_place_reviews cascade;
drop table if exists public.trust_reviews cascade;
drop table if exists public.reviews cascade;
drop table if exists public.settlement_members cascade;
drop table if exists public.settlements cascade;
drop table if exists public.student_email_verifications cascade;
drop table if exists public.saved_restaurants cascade;
drop table if exists public.saved_meetings cascade;
drop table if exists public.blocked_matches cascade;
drop table if exists public.messages cascade;
drop table if exists public.meeting_members cascade;
drop table if exists public.meetings cascade;
drop table if exists public.restaurants cascade;
drop table if exists public.users cascade;