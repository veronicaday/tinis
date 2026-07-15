# tini’s — Project Handoff

## Start here

Build a polished, private iPhone app called **tini’s**: a martini-rating club for Veronica and her friends. It should feel like Beli for martinis—social and opinionated—but begin as one invite-only friend group rather than a public network.

The supplied design reference is here:

`/Users/veronicaday/Library/Messages/Attachments/30/00/ABB89FDE-A45C-4911-8199-7446FB7A586D/4652C4B8-57AB-493A-9F1E-F57EC5CF6B26.PNG`

Use it as the primary visual reference. Preserve its editorial, upscale dark-green/cream/gold feeling, but use the product name **tini’s**, not “Very Cold.”

## Current implementation status

A buildable SwiftUI prototype now lives in `Tinis/Tinis.xcodeproj`, with the primary implementation in `Tinis/TinisApp.swift`. It has been built, installed, and visually tested on an iPhone 15 Pro simulator running iOS 17.5.

Implemented locally:

- branded welcome screen with original code-native martini artwork;
- custom five-item bottom navigation with a raised Add action;
- polished Home leaderboard, date filters, venue artwork, and detail sheet;
- custom search experience;
- three-step Add Martini flow with direct score, basics, five-position trait controls, and Elo comparison;
- Rankings and Profile screens consistent with the supplied dark-green, cream, and gold mockup;
- local demo data and in-session rating updates.

Still required for a distributable v1: persistence, Supabase authentication/data sync, invite codes, Apple Maps search, real photo capture/storage, safety/account controls, production signing, and TestFlight setup.

## Locked v1 decisions

- Platform: native iPhone app, SwiftUI, iOS 17+.
- Audience: a small adult friend group; one shared, invite-only club.
- Distribution: external TestFlight beta, with friends invited by email.
- Sign-in: passwordless email magic link, followed by a club invite code.
- Venue selection: Apple Maps search, with a manual-entry fallback.
- Rating subject: the venue’s martini (for example, “Bemelmans Bar”), not a global drink database.
- Direct score: required 1.0–10.0 rating in 0.1 increments.
- Traits: optional five-position controls for dirtiness, chilliness, uniqueness, and spirit-forwardness.
- Basics: spirit, garnish, serving style, date/time, optional price, optional photo, “would order again,” and a private note.
- Ranking: after a rating, show one quick head-to-head comparison with a similarly ranked past martini. This updates a separate personal Elo ranking; do not blend Elo into the visible 1–10 score.
- Shared leaderboard: based on friends’ direct scores, using each person’s latest rating for a venue.

## Product shape

Use a five-tab navigation structure.

1. **Home** — club “Top Martinis,” with all-time, year, and month filters; show score, rating count, location, and club activity.
2. **Search** — Apple Maps place search and a list of previously rated venues.
3. **Add** — guided rating flow: venue/details → score and optional traits → quick Elo comparison.
4. **Rankings** — personal Elo list plus club category lists such as Best Overall, Dirtiest, Coldest, Most Unique, and Most Spirit-Forward.
5. **Profile** — average rating, favorite venue, number of ratings, and taste insights once enough data exists.

Venue details should show the current user’s latest rating, prior visits, aggregate club score, friend scores, and trait summary.

Keep these out of v1: multiple clubs, public discovery, following people, comments, push notifications, Android, web, and payments.

## Design direction

- Dark forest backgrounds, warm cream cards, muted-gold dividers and accents, and a restrained blush state color.
- Editorial serif headings with a clean system sans-serif for controls. Use system fonts such as New York and SF Pro to avoid licensing work.
- Rounded cards, fine borders, generous whitespace, delicate line icons, and an olive/cocktail-pick mark.
- Match the mockup’s high-end, slightly playful cocktail-club mood. Avoid generic “bar app” styling.
- Create original brand imagery and iconography; do not reuse mockup photography unless Veronica owns rights to it.

## Recommended technical approach

### iOS app

- SwiftUI with a small, testable feature structure: Auth, Club, Venues, Ratings, Rankings, Profile, and shared Design System.
- Native Apple Maps / MapKit search for places.
- Camera and photo-library support should be optional; the rating flow must work without either permission.
- Persist drafts and a recent read cache locally so an interrupted rating can be resumed.

### Shared backend

Use **Supabase** for email authentication, Postgres, row-level permissions, and private image storage. It is a better fit than trying to make each friend’s personal iCloud account serve as a social backend.

Core data concepts:

- `Profile`: authenticated member, display name, avatar/preferences.
- `Club` and `Membership`: one private club, owner/admin role, join-by-invite-code.
- `Venue`: normalized name, address, latitude, longitude, and optional Apple Maps metadata.
- `VisitRating`: a dated rating/visit with direct score, optional traits, basics, photo, and private note.
- `PersonalVenueRank`: one Elo state per user and venue.
- `Comparison`: the win/loss/tie result used for Elo.
- `Block` and `Report`: basic safety controls.

Apply database access rules so club members can read only their own club; people can create, edit, and delete only their own ratings; and images are delivered with expiring signed links.

## Ranking rules

### Direct rating

The direct score is always the person’s own 1.0–10.0 judgment. It is what appears prominently on venue detail and friend-rating cards.

### Personal Elo ranking

- Start each venue at Elo 1500 for that person.
- After saving a rating, compare it with the closest-ranked venue that the person has already rated.
- Offer: “New martini,” “Past martini,” “Too close,” or “Skip.”
- Use standard Elo expected-score calculations; a tie has a 0.5 result.
- Use K=64 for a venue’s first three comparisons, then K=32.
- Sort the personal ranking by Elo; use direct score and recency only to break a tie.

This keeps the score understandable while making ranking feel playful and dynamic.

### Club leaderboard

- Take every member’s latest direct score for each venue.
- Calculate a lightly Bayesian-smoothed average, using two club-average “prior” ratings, so a single perfect score cannot dominate.
- Always show the number of ratings beside the club score.
- Trait categories use available trait values and display their rating counts when sparse.

## Privacy and App Review baseline

- Do not add public comments or anonymous posting in v1.
- Include block user, report content, and club-owner removal controls.
- Include an in-app account-deletion action, a privacy policy, a support contact, and accurate privacy disclosures.
- Declare alcohol references correctly in Apple’s age-rating questionnaire. Do not frame the product as a drinking game or encourage unsafe drinking.
- Allow manual venue entry when location access is unavailable or declined.

## TestFlight plan

TestFlight is the right first distribution method for this project.

- An Apple Developer Program membership is required and costs $99/year.
- Upload the first beta build to App Store Connect, submit it for beta review, then invite friends by email to a private external testing group.
- External TestFlight builds expire after 90 days; upload a refreshed build every 60–75 days.
- Give Apple’s beta reviewer a valid invite code and clear sign-in instructions in the review notes.
- Do not use a public TestFlight link for the friend club.

Later, if the app becomes a stable private product, submit it for full App Review and request **unlisted App Store distribution**. That gives a permanent direct App Store link, but anyone with the link can download it—so keep the in-app invite gate.

Useful Apple references:

- https://developer.apple.com/testflight/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://developer.apple.com/support/unlisted-app-distribution/
- https://developer.apple.com/app-store/review/guidelines/

## Acceptance criteria for v1

- A friend can install through TestFlight, authenticate by email, enter the invite code, and reach the club home screen.
- A member can find or manually add a venue, save a martini rating in under one minute, and complete or skip the quick Elo comparison.
- The member sees their personal ranking update immediately and the club leaderboard update after sync.
- Members cannot access another club’s data or edit someone else’s rating.
- Interrupted rating forms, denied photo/location permissions, failed uploads, and expired magic links have clear recovery states.
- The finished app feels materially consistent with the supplied design reference on both a compact and a large iPhone.

## Suggested first instruction in the new account

> Build the `tini’s` iOS app described in the attached `tinis-handoff.md`. Start by creating the SwiftUI project and its visual design system, then implement a polished local/demo data version of onboarding, Home, Add, Rankings, venue details, and Profile before connecting Supabase and TestFlight. Use the supplied PNG as the visual reference.
