# tini’s

Beli for matinia

## Open it

1. Open `Tinis/Tinis.xcodeproj` in Xcode.
2. Choose an iPhone simulator running iOS 17 or later.
3. Press Run.

The app is connected to Supabase and includes passwordless email sign-in, an invite-only club, a friend feed, shared ratings, trait-based rankings, and private photo storage. Local demo data remains available only when Supabase configuration is missing.

## Friend setup

1. A friend installs the app through TestFlight.
2. They enter their email and open the one-time sign-in link on that iPhone.
3. They enter the club invite code `DIRTY`.

The starter invite permits up to 10 members. Backend details and recovery notes are in `docs/SUPABASE_SETUP.md`.
