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

The Google restaurant discovery migration is `supabase/migrations/202607180004_add_google_place_discovery.sql`. It was applied on July 18, 2026. It stores Google place IDs, safely links legacy name-based venues when they are rated again, and exposes restaurant identity through the private friend-feed and leaderboard views.

It creates the profiles, clubs, memberships, invites, venues, ratings, private notes, personal ranks, comparisons, blocks, and reports tables. It also installs row-level security policies, friend-feed and leaderboard views, rating RPCs, and the private `rating-photos` storage bucket.

The starter club is `tini's martini club`. Its invite code is provisioned directly in Supabase and is never stored in this repository.

## Authentication

While Apple Developer enrollment is pending, the app uses Supabase passwordless email links with the `tinis://login-callback` URL scheme. The link must be opened on the iPhone or simulator where the sign-in request began so the PKCE session can complete.

The native Sign in with Apple implementation remains in the codebase for re-enabling after enrollment is active. Enable the Apple provider in Supabase Auth and add the native bundle identifier `com.veronicaday.tinis` to its Client IDs.

Manual identity linking is enabled during the transition so an existing email-authenticated member can attach Apple to the same Supabase user without losing ratings.

When Apple sign-in is restored, the Xcode target must use an Apple Developer team with the Sign in with Apple capability enabled. Native-only Apple authentication does not require a Services ID, web redirect, or six-month client-secret rotation.

## Database password

The generated database password was not saved. The iOS app and Supabase SQL editor do not need it. If direct database or CLI access is needed later, reset it in the Supabase project database settings and save the replacement in a password manager.
