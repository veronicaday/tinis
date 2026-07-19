import Foundation
import Supabase

enum TinisBackendPhase: Equatable {
    case checking
    case signedOut
    case needsAppleLink
    case needsInvite
    case ready
    case unavailable
}

struct TinisMembershipRow: Decodable {
    let clubID: UUID

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
    }
}

struct TinisClubFriend: Decodable, Equatable, Identifiable {
    let id: UUID
    let displayName: String
    var avatarPath: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }
}

struct TinisFriendFeedRow: Decodable, Equatable, Identifiable {
    let id: UUID
    let clubID: UUID
    let userID: UUID
    let displayName: String
    let avatarPath: String?
    let venueID: UUID
    let venueName: String
    let city: String
    let region: String
    let score: Double
    let dirtiness: Double?
    let chilliness: Double?
    let uniqueness: Double?
    let spiritForward: Double?
    let publicNote: String?
    let photoPath: String?
    let spirit: String?
    let garnish: String?
    let servingStyle: String?
    let price: Double?
    let companions: [String]?
    let visitedAt: String?
    let cheersCount: Int?
    let cheeredByMe: Bool?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case clubID = "club_id"
        case userID = "user_id"
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case venueID = "venue_id"
        case venueName = "venue_name"
        case city, region, score, dirtiness, chilliness, uniqueness, spirit, garnish, price, companions
        case spiritForward = "spirit_forward"
        case servingStyle = "serving_style"
        case publicNote = "public_note"
        case photoPath = "photo_path"
        case visitedAt = "visited_at"
        case cheersCount = "cheers_count"
        case cheeredByMe = "cheered_by_me"
        case createdAt = "created_at"
    }
}

struct TinisLeaderboardRow: Decodable, Equatable, Identifiable {
    let clubID: UUID
    let venueID: UUID
    let venueName: String
    let city: String
    let region: String
    let score: Double
    let ratingCount: Int
    let dirtiness: Double?
    let chilliness: Double?
    let uniqueness: Double?
    let spiritForward: Double?
    let spirit: String?
    let garnish: String?
    let servingStyle: String?
    let price: Double?
    let publicNote: String?
    let companions: [String]?
    let ratingID: UUID?
    let ratingUserID: UUID?
    let isOwnRating: Bool?
    let latestVisit: String

    var id: UUID { venueID }

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case venueID = "venue_id"
        case venueName = "venue_name"
        case city, region, score, dirtiness, chilliness, uniqueness
        case ratingCount = "rating_count"
        case spiritForward = "spirit_forward"
        case spirit, garnish, price, companions
        case servingStyle = "serving_style"
        case publicNote = "public_note"
        case ratingID = "detail_rating_id"
        case ratingUserID = "detail_user_id"
        case isOwnRating = "is_own_rating"
        case latestVisit = "latest_visit"
    }
}

struct TinisCheersState: Equatable {
    var count: Int
    var isCheered: Bool
}

private struct SaveRatingParameters: Encodable {
    let clubID: UUID
    let venueName: String
    let location: String
    let score: Double
    let dirtiness: Double
    let chilliness: Double
    let uniqueness: Double
    let spiritForward: Double
    let spirit: String
    let garnish: String
    let servingStyle: String
    let price: Double?

    enum CodingKeys: String, CodingKey {
        case clubID = "p_club_id"
        case venueName = "p_venue_name"
        case location = "p_location"
        case score = "p_score"
        case dirtiness = "p_dirtiness"
        case chilliness = "p_chilliness"
        case uniqueness = "p_uniqueness"
        case spiritForward = "p_spirit_forward"
        case spirit = "p_spirit"
        case garnish = "p_garnish"
        case servingStyle = "p_serving_style"
        case price = "p_price"
    }
}

private struct LegacySaveRatingParameters: Encodable {
    let clubID: UUID
    let venueName: String
    let location: String
    let score: Double
    let dirtiness: Double
    let chilliness: Double
    let uniqueness: Double
    let spiritForward: Double
    let spirit: String
    let garnish: String
    let price: Double?

    enum CodingKeys: String, CodingKey {
        case clubID = "p_club_id"
        case venueName = "p_venue_name"
        case location = "p_location"
        case score = "p_score"
        case dirtiness = "p_dirtiness"
        case chilliness = "p_chilliness"
        case uniqueness = "p_uniqueness"
        case spiritForward = "p_spirit_forward"
        case spirit = "p_spirit"
        case garnish = "p_garnish"
        case price = "p_price"
    }
}

private struct RatingDetailsUpdate: Encodable {
    let publicNote: String?
    let visitedAt: String

    enum CodingKeys: String, CodingKey {
        case publicNote = "public_note"
        case visitedAt = "visited_at"
    }
}

private struct RatingCompanionInsert: Encodable {
    let ratingID: UUID
    let companionID: UUID

    enum CodingKeys: String, CodingKey {
        case ratingID = "rating_id"
        case companionID = "companion_id"
    }
}

private struct RatingEditUpdate: Encodable {
    let dirtiness: Double
    let chilliness: Double
    let uniqueness: Double
    let spiritForward: Double
    let spirit: String
    let garnish: String
    let servingStyle: String
    let price: Double?
    let publicNote: String?
    let visitedAt: String

    enum CodingKeys: String, CodingKey {
        case dirtiness, chilliness, uniqueness, spirit, garnish, price
        case spiritForward = "spirit_forward"
        case servingStyle = "serving_style"
        case publicNote = "public_note"
        case visitedAt = "visited_at"
    }
}

private struct RatingCheerInsert: Encodable {
    let ratingID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case ratingID = "rating_id"
        case userID = "user_id"
    }
}

private struct ProfileUpdate: Encodable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private struct ProfileAvatarUpdate: Encodable {
    let avatarPath: String

    enum CodingKeys: String, CodingKey {
        case avatarPath = "avatar_path"
    }
}

@MainActor
final class TinisBackend: ObservableObject {
    @Published private(set) var phase: TinisBackendPhase = .checking
    @Published private(set) var friendFeed: [TinisFriendFeedRow] = []
    @Published private(set) var leaderboard: [TinisLeaderboardRow] = []
    @Published private(set) var clubFriends: [TinisClubFriend] = []
    @Published private(set) var currentUserID: UUID?
    @Published private(set) var currentDisplayName: String?
    @Published private(set) var avatarURLs: [UUID: URL] = [:]
    @Published private(set) var cheersByRating: [UUID: TinisCheersState] = [:]
    @Published private(set) var photoURLs: [UUID: URL] = [:]
    @Published var errorMessage: String?

    private let client: SupabaseClient?
    private(set) var clubID: UUID?
    private var currentAvatarPath: String?

    var isConfigured: Bool { client != nil }
    var isReady: Bool { phase == .ready && clubID != nil }
    var currentProfilePhotoURL: URL? {
        guard let currentUserID else { return nil }
        return avatarURLs[currentUserID]
    }

    init(bundle: Bundle = .main) {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            client = nil
            phase = .unavailable
            return
        }
#endif
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !key.isEmpty,
            !key.contains("YOUR_")
        else {
            client = nil
            phase = .unavailable
            return
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    func start() async {
        guard let client else {
            phase = .unavailable
            return
        }

        do {
            let session = try await client.auth.session
            let hasAppleIdentity = session.user.identities?.contains {
                $0.provider.caseInsensitiveCompare("apple") == .orderedSame
            } ?? false

            if hasAppleIdentity {
                await loadMembership()
            } else {
                phase = .needsAppleLink
            }
        } catch {
            phase = .signedOut
        }
    }

    func continueWithApple(
        idToken: String,
        nonce: String,
        displayName: String?,
        linkExistingAccount: Bool
    ) async {
        guard let client else { return }
        errorMessage = nil

        do {
            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
            let session: Session
            if linkExistingAccount {
                session = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
            } else {
                session = try await client.auth.signInWithIdToken(credentials: credentials)
            }

            let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmedName, !trimmedName.isEmpty {
                _ = try? await client.auth.update(
                    user: UserAttributes(data: ["display_name": .string(trimmedName)])
                )
                try? await client
                    .from("profiles")
                    .update(ProfileUpdate(displayName: trimmedName))
                    .eq("id", value: session.user.id)
                    .execute()
                currentDisplayName = trimmedName
            }

            await loadMembership()
        } catch {
            errorMessage = linkExistingAccount
                ? "Apple could not be connected to this account. Please try again."
                : "Apple sign-in could not be completed. Please try again."
            phase = linkExistingAccount ? .needsAppleLink : .signedOut
        }
    }

    func reportSignInError(_ message: String) {
        errorMessage = message
    }

    func updateDisplayName(_ name: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmedName.count) else {
            errorMessage = "Your display name must be between 1 and 40 characters."
            return false
        }

        guard let client else {
            currentDisplayName = trimmedName
            return true
        }

        errorMessage = nil
        do {
            let userID = try await client.auth.session.user.id
            try await client
                .from("profiles")
                .update(ProfileUpdate(displayName: trimmedName))
                .eq("id", value: userID)
                .execute()
            currentDisplayName = trimmedName
            await refreshSharedData()
            return true
        } catch {
            errorMessage = "Your profile could not be updated. Please try again."
            return false
        }
    }

    func updateProfilePhoto(_ photoData: Data) async -> Bool {
        guard let client else { return true }

        errorMessage = nil
        do {
            let userID = try await client.auth.session.user.id
            let photoPath = [
                userID.uuidString.lowercased(),
                "\(UUID().uuidString.lowercased()).jpg"
            ].joined(separator: "/")

            try await client.storage
                .from("profile-photos")
                .upload(
                    photoPath,
                    data: photoData,
                    options: FileOptions(contentType: "image/jpeg")
                )

            do {
                try await client
                    .from("profiles")
                    .update(ProfileAvatarUpdate(avatarPath: photoPath))
                    .eq("id", value: userID)
                    .execute()
            } catch {
                _ = try? await client.storage
                    .from("profile-photos")
                    .remove(paths: [photoPath])
                throw error
            }

            if let oldAvatarPath = currentAvatarPath, oldAvatarPath != photoPath {
                _ = try? await client.storage
                    .from("profile-photos")
                    .remove(paths: [oldAvatarPath])
            }

            currentAvatarPath = photoPath
            avatarURLs[userID] = try? await client.storage
                .from("profile-photos")
                .createSignedURL(path: photoPath, expiresIn: 60 * 60)
            await refreshSharedData()
            return true
        } catch {
            errorMessage = "Your profile photo could not be uploaded. Please try again."
            return false
        }
    }

    func signOut() async {
        if let client {
            try? await client.auth.signOut()
        }
        clubID = nil
        friendFeed = []
        leaderboard = []
        clubFriends = []
        currentUserID = nil
        currentDisplayName = nil
        currentAvatarPath = nil
        avatarURLs = [:]
        cheersByRating = [:]
        photoURLs = [:]
        errorMessage = nil
        phase = .signedOut
    }

    func joinClub(code: String) async {
        guard let client else { return }
        errorMessage = nil
        do {
            let joinedClubID: UUID = try await client
                .rpc("join_club", params: ["invite_code": code.uppercased()])
                .execute()
                .value
            clubID = joinedClubID
            phase = .ready
            await refreshSharedData()
        } catch {
            errorMessage = "That invite code did not work. Check it and try again."
        }
    }

    func saveRating(
        _ venue: MartiniVenue,
        price: String,
        spirit: String,
        garnish: String,
        servingStyle: String,
        visitDate: Date,
        companionIDs: [UUID],
        photoData: Data?
    ) async throws -> String? {
        guard let client, let clubID else { return nil }

        let parameters = SaveRatingParameters(
            clubID: clubID,
            venueName: venue.name,
            location: venue.location,
            score: venue.score,
            dirtiness: venue.dirtiness,
            chilliness: venue.chilliness,
            uniqueness: venue.uniqueness,
            spiritForward: venue.spiritForward,
            spirit: spirit.lowercased(),
            garnish: garnish.lowercased(),
            servingStyle: servingStyle.lowercased(),
            price: Double(price)
        )

        let ratingID: UUID
        do {
            ratingID = try await client
                .rpc("save_rating", params: parameters)
                .execute()
                .value
        } catch {
            let failure = "\(error.localizedDescription) \(String(describing: error))".lowercased()
            guard
                failure.contains("p_serving_style") ||
                failure.contains("function") ||
                failure.contains("schema cache")
            else {
                throw error
            }
            let legacyParameters = LegacySaveRatingParameters(
                clubID: clubID,
                venueName: venue.name,
                location: venue.location,
                score: venue.score,
                dirtiness: venue.dirtiness,
                chilliness: venue.chilliness,
                uniqueness: venue.uniqueness,
                spiritForward: venue.spiritForward,
                spirit: spirit.lowercased(),
                garnish: garnish.lowercased(),
                price: Double(price)
            )
            ratingID = try await client
                .rpc("save_rating", params: legacyParameters)
                .execute()
                .value
        }

        var saveIssues: [String] = []
        let trimmedNote = venue.note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await client
                .from("ratings")
                .update(RatingDetailsUpdate(
                    publicNote: trimmedNote.isEmpty ? nil : trimmedNote,
                    visitedAt: ISO8601DateFormatter().string(from: visitDate)
                ))
                .eq("id", value: ratingID)
                .execute()
        } catch {
            saveIssues.append("its date or note")
        }

        if !companionIDs.isEmpty {
            do {
                try await client
                    .from("rating_companions")
                    .insert(companionIDs.map { RatingCompanionInsert(ratingID: ratingID, companionID: $0) })
                    .execute()
            } catch {
                saveIssues.append("friend tags")
            }
        }

        if let photoData {
            do {
                let userID = try await client.auth.session.user.id
                let photoPath = [
                    clubID.uuidString.lowercased(),
                    userID.uuidString.lowercased(),
                    "\(ratingID.uuidString.lowercased()).jpg"
                ].joined(separator: "/")

                try await client.storage
                    .from("rating-photos")
                    .upload(
                        photoPath,
                        data: photoData,
                        options: FileOptions(contentType: "image/jpeg")
                    )

                do {
                    try await client
                        .from("ratings")
                        .update(["photo_path": photoPath])
                        .eq("id", value: ratingID)
                        .execute()
                } catch {
                    _ = try? await client.storage
                        .from("rating-photos")
                        .remove(paths: [photoPath])
                    throw error
                }
            } catch {
                saveIssues.append("the photo")
            }
        }

        await refreshSharedData()
        guard !saveIssues.isEmpty else { return nil }
        return "Your rating was saved, but \(saveIssues.joined(separator: ", ")) could not be added. You can try again later."
    }

    func updateRating(
        id ratingID: UUID,
        venue: MartiniVenue,
        visitDate: Date,
        companionIDs: [UUID]
    ) async -> Bool {
        guard let client else { return true }

        errorMessage = nil
        let trimmedNote = venue.note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await client
                .from("ratings")
                .update(RatingEditUpdate(
                    dirtiness: venue.dirtiness,
                    chilliness: venue.chilliness,
                    uniqueness: venue.uniqueness,
                    spiritForward: venue.spiritForward,
                    spirit: venue.spirit.lowercased(),
                    garnish: venue.garnish.lowercased(),
                    servingStyle: venue.servingStyle.lowercased(),
                    price: venue.price,
                    publicNote: trimmedNote.isEmpty ? nil : trimmedNote,
                    visitedAt: ISO8601DateFormatter().string(from: visitDate)
                ))
                .eq("id", value: ratingID)
                .execute()

            try await client
                .from("rating_companions")
                .delete()
                .eq("rating_id", value: ratingID)
                .execute()

            if !companionIDs.isEmpty {
                try await client
                    .from("rating_companions")
                    .insert(companionIDs.map { RatingCompanionInsert(ratingID: ratingID, companionID: $0) })
                    .execute()
            }

            await refreshSharedData()
            return true
        } catch {
            errorMessage = "Your rating could not be updated. Please try again."
            return false
        }
    }

    func toggleCheers(for ratingID: UUID) async {
        guard let client else { return }
        let resolvedUserID: UUID?
        if let currentUserID {
            resolvedUserID = currentUserID
        } else {
            resolvedUserID = try? await client.auth.session.user.id
        }
        guard let userID = resolvedUserID else { return }

        let previous = cheersByRating[ratingID] ?? TinisCheersState(count: 0, isCheered: false)
        cheersByRating[ratingID] = TinisCheersState(
            count: max(0, previous.count + (previous.isCheered ? -1 : 1)),
            isCheered: !previous.isCheered
        )

        do {
            if previous.isCheered {
                try await client
                    .from("rating_cheers")
                    .delete()
                    .eq("rating_id", value: ratingID)
                    .eq("user_id", value: userID)
                    .execute()
            } else {
                try await client
                    .from("rating_cheers")
                    .insert(RatingCheerInsert(ratingID: ratingID, userID: userID))
                    .execute()
            }
            await refreshSharedData()
        } catch {
            cheersByRating[ratingID] = previous
            errorMessage = "Your cheers could not be saved. Please try again."
        }
    }

    func refreshSharedData() async {
        guard let client, clubID != nil else { return }
        do {
            let signedInUserID = try? await client.auth.session.user.id
            currentUserID = signedInUserID
            async let feedRequest: [TinisFriendFeedRow] = client
                .from("friend_feed")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            async let leaderboardRequest: [TinisLeaderboardRow] = client
                .from("club_leaderboard")
                .select()
                .order("score", ascending: false)
                .execute()
                .value

            let (newFeed, newLeaderboard) = try await (feedRequest, leaderboardRequest)
            var newPhotoURLs: [UUID: URL] = [:]
            for row in newFeed {
                guard let photoPath = row.photoPath else { continue }
                newPhotoURLs[row.id] = try? await client.storage
                    .from("rating-photos")
                    .createSignedURL(path: photoPath, expiresIn: 60 * 60)
            }
            friendFeed = newFeed
            leaderboard = newLeaderboard
            photoURLs = newPhotoURLs
            cheersByRating = Dictionary(uniqueKeysWithValues: newFeed.map {
                ($0.id, TinisCheersState(count: $0.cheersCount ?? 0, isCheered: $0.cheeredByMe ?? false))
            })

            if let currentUserID = signedInUserID,
               let profiles: [TinisClubFriend] = try? await client
                .from("profiles")
                .select("id, display_name, avatar_path")
                .order("display_name")
                .execute()
                .value {
                var newAvatarURLs: [UUID: URL] = [:]
                for profile in profiles {
                    guard let avatarPath = profile.avatarPath else { continue }
                    newAvatarURLs[profile.id] = try? await client.storage
                        .from("profile-photos")
                        .createSignedURL(path: avatarPath, expiresIn: 60 * 60)
                }
                let currentProfile = profiles.first(where: { $0.id == currentUserID })
                currentDisplayName = currentProfile?.displayName
                currentAvatarPath = currentProfile?.avatarPath
                avatarURLs = newAvatarURLs
                clubFriends = profiles.filter { $0.id != currentUserID }
            }
        } catch {
            errorMessage = "The club could not refresh just now. Your saved data is still safe."
        }
    }

    private func loadMembership() async {
        guard let client else { return }
        do {
            let memberships: [TinisMembershipRow] = try await client
                .from("club_memberships")
                .select("club_id")
                .limit(1)
                .execute()
                .value

            if let membership = memberships.first {
                clubID = membership.clubID
                phase = .ready
                await refreshSharedData()
            } else {
                phase = .needsInvite
            }
        } catch {
            errorMessage = error.localizedDescription
            phase = .needsInvite
        }
    }
}
