# Supabase setup

## Project

- Supabase project: `Tinis`
- Project reference: `miiokelwxgczoestkmve`
- Project URL: `https://miiokelwxgczoestkmve.supabase.co`
- Dashboard: `https://supabase.com/dashboard/project/miiokelwxgczoestkmve`

## Local app configuration

`Tinis/Config/Secrets.xcconfig` contains the app-safe public project URL and anon key. It is intentionally ignored by Git. Never put a Supabase secret or `service_role` key in the iOS app.

For a new checkout, copy `Tinis/Config/Secrets.xcconfig.example` to `Tinis/Config/Secrets.xcconfig` and fill in the project URL and public key.

## Database

The initial migration is `supabase/migrations/202607150001_initial_tinis_schema.sql`. It was applied to the project on July 15, 2026.

It creates the profiles, clubs, memberships, invites, venues, ratings, private notes, personal ranks, comparisons, blocks, and reports tables. It also installs row-level security policies, friend-feed and leaderboard views, rating RPCs, and the private `rating-photos` storage bucket.

The starter club is `tini's martini club`. Its invite code is `DIRTY`, with a maximum of 10 uses.

## Authentication

Supabase email magic-link sign-in is enabled. The allowed redirect URL is:

`tinis://login-callback`

The same custom URL scheme is registered in `Tinis/Info.plist`.

## Database password

The generated database password was not saved. The iOS app and Supabase SQL editor do not need it. If direct database or CLI access is needed later, reset it in the Supabase project database settings and save the replacement in a password manager.
