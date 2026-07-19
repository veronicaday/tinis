# tini’s

Beli but for martinis

## Open it

1. Open `Tinis/Tinis.xcodeproj` in Xcode.
2. Choose an iPhone simulator running iOS 17 or later.
3. Press Run.

The app is connected to Supabase and includes Sign in with Apple, an invite-only club, a friend feed, shared ratings, trait-based rankings, and private photo storage. Local demo data remains available only when Supabase configuration is missing.

## Friend setup

1. A friend installs the app through TestFlight.
2. They continue with Apple and confirm with Face ID.
3. The first time, they choose a display name and enter the club code shared with them privately.
4. Their Apple Account reconnects them to the same profile and ratings on another device.

Club codes are server-side credentials and must never be committed to source control. Backend details and recovery notes are in `docs/SUPABASE_SETUP.md`.
