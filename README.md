# tini’s

Beli but for martinis

## Open it

1. Open `Tinis/Tinis.xcodeproj` in Xcode.
2. Choose an iPhone simulator running iOS 17 or later.
3. Press Run.

The app is connected to Supabase and includes private email-link sign-in, an invite-only club, restaurant discovery through Google Places, a friend feed, shared ratings, trait-based rankings, and private photo storage. Local demo data remains available only when Supabase configuration is missing.

## Friend setup

1. A friend installs the app through TestFlight.
2. They enter their email and open the one-time sign-in link on that device.
3. The first time, they choose a display name and enter the club code shared with them privately.
4. Their email reconnects them to the same profile and ratings on another device.

Club codes are server-side credentials and must never be committed to source control. Backend details and recovery notes are in `docs/SUPABASE_SETUP.md`.
