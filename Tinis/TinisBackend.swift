import Foundation
import Supabase

enum TinisBackendPhase: Equatable {
    case checking
    case signedOut
    case emailSent(String)
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

struct TinisFriendFeedRow: Decodable, Equatable, Identifiable {
    let id: UUID
    let clubID: UUID
    let userID: UUID
    let displayName: String
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
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case clubID = "club_id"
        case userID = "user_id"
        case displayName = "display_name"
        case venueID = "venue_id"
        case venueName = "venue_name"
        case city, region, score, dirtiness, chilliness, uniqueness
        case spiritForward = "spirit_forward"
        case publicNote = "public_note"
        case photoPath = "photo_path"
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
    let latestVisit: String

    var id: UUID { venueID }

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case venueID = "venue_id"
        case venueName = "venue_name"
        case city, region, score, dirtiness, chilliness, uniqueness
        case ratingCount = "rating_count"
        case spiritForward = "spirit_forward"
        case latestVisit = "latest_visit"
    }
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

@MainActor
final class TinisBackend: ObservableObject {
    @Published private(set) var phase: TinisBackendPhase = .checking
    @Published private(set) var friendFeed: [TinisFriendFeedRow] = []
    @Published private(set) var leaderboard: [TinisLeaderboardRow] = []
    @Published private(set) var photoURLs: [UUID: URL] = [:]
    @Published var errorMessage: String?

    private let client: SupabaseClient?
    private(set) var clubID: UUID?

    var isConfigured: Bool { client != nil }
    var isReady: Bool { phase == .ready && clubID != nil }

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
            _ = try await client.auth.session
            await loadMembership()
        } catch {
            phase = .signedOut
        }
    }

    func sendMagicLink(to email: String) async {
        guard let client else { return }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@") else {
            errorMessage = "Enter a valid email address."
            return
        }

        errorMessage = nil
        do {
            try await client.auth.signInWithOTP(
                email: normalizedEmail,
                redirectTo: URL(string: "tinis://login-callback")!
            )
            phase = .emailSent(normalizedEmail)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleOpenURL(_ url: URL) async {
        guard let client, url.scheme == "tinis" else { return }
        errorMessage = nil
        do {
            _ = try await client.auth.session(from: url)
            await loadMembership()
        } catch {
            errorMessage = "That sign-in link could not be completed. Please request a new one."
            phase = .signedOut
        }
    }

    func useDifferentEmail() {
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

        var photoWarning: String?
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
                photoWarning = "Your rating was saved, but the photo could not upload. You can add it again later."
            }
        }

        await refreshSharedData()
        return photoWarning
    }

    func refreshSharedData() async {
        guard let client, clubID != nil else { return }
        do {
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
