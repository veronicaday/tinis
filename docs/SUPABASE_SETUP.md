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

The production app uses native Sign in with Apple. Supabase passwordless email links remain available as a temporary fallback using the `tinis://login-callback` URL scheme. An email link must be opened on the iPhone or simulator where the sign-in request began so the PKCE session can complete.

The Apple provider in Supabase Auth uses the native bundle identifier `com.veronicaday.tinis` as its Client ID.

Manual identity linking is enabled during the transition so an existing email-authenticated member can attach Apple to the same Supabase user without losing ratings.

The Xcode target uses the Apple Developer team with the Sign in with Apple capability enabled. Native-only Apple authentication does not require a Services ID, web redirect, or six-month client-secret rotation.

## Account deletion

The app's Settings screen calls the authenticated `delete-account` Edge Function. The function removes the member's Storage objects, transfers ownership of any shared club to its longest-standing remaining member, deletes an empty club, and finally deletes the Supabase Auth user. Database rows owned by that profile are then removed by foreign-key cascades.

Before deploying the function, apply `supabase/migrations/202607190002_prepare_account_deletion.sql`. It changes venue creator history to `ON DELETE SET NULL`, so an account can be removed without deleting a shared venue.

Deploy `supabase/functions/delete-account/index.ts` with Supabase's normal JWT verification enabled. Its service-role access must remain server-side; never copy the service-role key into the app or this repository.

The current native Apple flow does not retain an Apple refresh token, so the deletion flow cannot revoke the Sign in with Apple grant automatically. The app directs members who want to revoke that grant to Apple Account Settings after deletion. Automatic revocation can be added later by securely exchanging and retaining Apple's authorization code on the server.

## Privacy policy

The public policy source is `docs/privacy/index.html`, intended for GitHub Pages at `https://veronicaday.github.io/tinis/privacy/`. The same URL is linked from the in-app Settings screen and should be entered in App Store Connect.

## Database password

The generated database password was not saved. The iOS app and Supabase SQL editor do not need it. If direct database or CLI access is needed later, reset it in the Supabase project database settings and save the replacement in a password manager.
