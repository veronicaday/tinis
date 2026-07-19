import SwiftUI
import UIKit
import PhotosUI

@main
struct TinisApp: App {
    @StateObject private var app = TinisStore()
    @StateObject private var backend = TinisBackend()

    init() {
        TinisGooglePlaces.configure()
    }

    var body: some Scene {
        WindowGroup {
            TinisRootView()
                .environmentObject(app)
                .environmentObject(backend)
                .tint(TinisColor.gold)
                .task { await backend.start() }
        }
    }
}

// MARK: - Data

struct MartiniVenue: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var location: String
    var score: Double
    var ratingCount: Int
    var date: String
    var trait: String
    var dirtiness: Double
    var chilliness: Double
    var uniqueness: Double
    var spiritForward: Double
    var elo: Int
    var spirit: String = "Unknown"
    var garnish: String = "Unknown"
    var servingStyle: String = "Unknown"
    var price: Double? = nil
    var note: String = ""
    var companions: [String] = []
    var backendRatingID: UUID? = nil
    var ratingOwnerID: UUID? = nil
    var ratingOwnerName: String? = nil
    var isOwnRating: Bool = true
    var cheersCount: Int = 0
    var isCheered: Bool = false
    var visitedAt: String? = nil
}

enum DuelChoice: String {
    case new
    case old
    case tie
    case skip
}

enum TinisElo {
    static let startingRating = 1500
    private static let kFactor = 32.0

    static func updatedRatings(
        newRating: Int = startingRating,
        pastRating: Int,
        choice: DuelChoice?
    ) -> (new: Int, past: Int) {
        guard let choice, choice != .skip else { return (newRating, pastRating) }

        let actual: Double
        switch choice {
        case .new: actual = 1
        case .old: actual = 0
        case .tie: actual = 0.5
        case .skip: return (newRating, pastRating)
        }

        let expected = 1 / (1 + pow(10, Double(pastRating - newRating) / 400))
        let adjustment = Int((kFactor * (actual - expected)).rounded())
        return (newRating + adjustment, pastRating - adjustment)
    }

    static func displayScore(for rating: Int) -> Double {
        let score = 7.85 + Double(rating - startingRating) / 120
        return (min(10, max(1, score)) * 10).rounded() / 10
    }
}

struct FriendActivity: Identifiable {
    let id = UUID()
    let friend: String
    let initials: String
    let venueName: String
    let location: String
    let score: Double
    let trait: String
    let note: String
    let time: String
    let rankingUpdate: String
    let avatarHex: UInt
    let artworkVariant: Int
    let photoURL: URL?
    var avatarURL: URL? = nil
    var ratingID: UUID? = nil
    var userID: UUID? = nil
    var dirtiness: Double = 2
    var chilliness: Double = 2
    var uniqueness: Double = 2
    var spiritForward: Double = 2
    var spirit: String = "Unknown"
    var garnish: String = "Unknown"
    var servingStyle: String = "Unknown"
    var price: Double? = nil
    var companions: [String] = []
    var visitedAt: String? = nil
    var isOwnRating: Bool = false
    var cheersCount: Int = 0
    var isCheered: Bool = false
}

enum ProfileTopFilter: String, CaseIterable, Identifiable {
    case topRated = "Top Rated"
    case dirtiest = "Dirtiest"
    case cleanest = "Cleanest"
    case coldest = "Coldest"
    case warmest = "Warmest"
    case mostUnique = "Most Unique"
    case mostClassic = "Most Classic"
    case mostSpiritForward = "Most Spirit-Forward"
    case smoothest = "Smoothest"

    var id: String { rawValue }

    func sorted(_ venues: [MartiniVenue]) -> [MartiniVenue] {
        venues.sorted { first, second in
            switch self {
            case .topRated: return first.score > second.score
            case .dirtiest: return first.dirtiness > second.dirtiness
            case .cleanest: return first.dirtiness < second.dirtiness
            case .coldest: return first.chilliness > second.chilliness
            case .warmest: return first.chilliness < second.chilliness
            case .mostUnique: return first.uniqueness > second.uniqueness
            case .mostClassic: return first.uniqueness < second.uniqueness
            case .mostSpiritForward: return first.spiritForward > second.spiritForward
            case .smoothest: return first.spiritForward < second.spiritForward
            }
        }
    }

    var metricCaption: String {
        switch self {
        case .topRated: return "SCORE"
        case .dirtiest: return "DIRTINESS"
        case .cleanest: return "CLEAN"
        case .coldest: return "COLD"
        case .warmest: return "WARM"
        case .mostUnique: return "UNIQUE"
        case .mostClassic: return "CLASSIC"
        case .mostSpiritForward: return "SPIRIT"
        case .smoothest: return "SMOOTH"
        }
    }

    func metricValue(for venue: MartiniVenue) -> String {
        if self == .topRated { return String(format: "%.1f", venue.score) }

        let rawValue: Double
        let inverted: Bool
        switch self {
        case .dirtiest: rawValue = venue.dirtiness; inverted = false
        case .cleanest: rawValue = venue.dirtiness; inverted = true
        case .coldest: rawValue = venue.chilliness; inverted = false
        case .warmest: rawValue = venue.chilliness; inverted = true
        case .mostUnique: rawValue = venue.uniqueness; inverted = false
        case .mostClassic: rawValue = venue.uniqueness; inverted = true
        case .mostSpiritForward: rawValue = venue.spiritForward; inverted = false
        case .smoothest: rawValue = venue.spiritForward; inverted = true
        case .topRated: rawValue = 0; inverted = false
        }
        let intensity = inverted ? 4 - rawValue : rawValue
        let level = min(5, max(1, Int(intensity.rounded()) + 1))
        return "\(level)/5"
    }
}

@MainActor
final class TinisStore: ObservableObject {
    private static let onboardingKey = "tinis.hasEnteredClub"

    @Published var hasOnboarded: Bool {
        didSet {
            UserDefaults.standard.set(hasOnboarded, forKey: Self.onboardingKey)
        }
    }
    @Published var selectedTab = 0
    @Published var firstName = "Veronica"
    @Published var profilePhotoData: Data?
    @Published var selectedVenue: MartiniVenue?
    @Published var pendingGooglePlace: GooglePlaceSelection?
    @Published var venues: [MartiniVenue] = [
        .init(name: "Bemelmans Bar", location: "New York, NY", score: 8.9, ratingCount: 7, date: "May 12, 2024", trait: "cold, lightly dirty", dirtiness: 3.2, chilliness: 4.0, uniqueness: 2.1, spiritForward: 3.7, elo: 1628, spirit: "Gin", garnish: "Olive", servingStyle: "Up", price: 19, note: "Perfectly icy, briny, and balanced.", companions: ["Sarah", "Alex"]),
        .init(name: "Dante", location: "New York, NY", score: 8.7, ratingCount: 6, date: "Apr 28, 2024", trait: "bright, classic", dirtiness: 0.8, chilliness: 3.4, uniqueness: 1.1, spiritForward: 2.8, elo: 1606, spirit: "Gin", garnish: "Lemon", servingStyle: "Up", price: 18, note: "Bright citrus with a clean finish.", companions: ["Maya"]),
        .init(name: "Employees Only", location: "New York, NY", score: 8.4, ratingCount: 5, date: "May 15, 2024", trait: "clean, spirit-forward", dirtiness: 0.3, chilliness: 2.8, uniqueness: 3.1, spiritForward: 4.0, elo: 1574, spirit: "Gin", garnish: "Olive", servingStyle: "Up", price: 20, note: "A strong pour with a silky texture.", companions: ["Jack"]),
        .init(name: "The Savoy", location: "London, UK", score: 8.3, ratingCount: 4, date: "Feb 9, 2024", trait: "silky, perfectly cold", dirtiness: 1.4, chilliness: 3.9, uniqueness: 1.7, spiritForward: 2.3, elo: 1558, spirit: "Gin", garnish: "Lemon", servingStyle: "Up", price: 22, note: "Classic, elegant, and extremely cold."),
        .init(name: "Clover Club", location: "Brooklyn, NY", score: 8.1, ratingCount: 3, date: "Jan 20, 2024", trait: "soft, lemony", dirtiness: 3.8, chilliness: 2.2, uniqueness: 4.0, spiritForward: 1.2, elo: 1531, spirit: "Gin", garnish: "Olive", servingStyle: "Up", price: 16, note: "Great price for a playful dirty martini.", companions: ["Sarah", "Maya"])
    ]

    init() {
        let storedOnboardingState = UserDefaults.standard.bool(forKey: Self.onboardingKey)
#if DEBUG
        let launchArguments = ProcessInfo.processInfo.arguments
        if launchArguments.contains("-ui-testing") {
            hasOnboarded = !launchArguments.contains("-ui-testing-welcome")
        } else {
            hasOnboarded = storedOnboardingState
        }
        if launchArguments.contains("-ui-testing-search") {
            selectedTab = 1
        }
#else
        hasOnboarded = storedOnboardingState
#endif
    }

    var topVenue: MartiniVenue { venues.sorted { $0.elo > $1.elo }.first! }

    func existingVenue(named name: String, location: String) -> MartiniVenue? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        return venues.first {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame &&
            $0.location.localizedCaseInsensitiveCompare(trimmedLocation) == .orderedSame
        }
    }

    func topVenue(excluding venue: MartiniVenue?) -> MartiniVenue? {
        venues
            .filter { $0.id != venue?.id }
            .sorted { $0.elo > $1.elo }
            .first
    }

    func updateElo(for venue: MartiniVenue, to elo: Int) {
        guard let index = venues.firstIndex(where: { $0.id == venue.id }) else { return }
        venues[index].elo = elo
        venues[index].score = TinisElo.displayScore(for: elo)
    }

    func add(_ venue: MartiniVenue) {
        if let index = venues.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(venue.name) == .orderedSame &&
            $0.location.localizedCaseInsensitiveCompare(venue.location) == .orderedSame
        }) {
            venues[index].score = venue.score
            venues[index].ratingCount += 1
            venues[index].date = venue.date
            venues[index].trait = venue.trait
            venues[index].dirtiness = venue.dirtiness
            venues[index].chilliness = venue.chilliness
            venues[index].uniqueness = venue.uniqueness
            venues[index].spiritForward = venue.spiritForward
            venues[index].elo = venue.elo
            venues[index].spirit = venue.spirit
            venues[index].garnish = venue.garnish
            venues[index].servingStyle = venue.servingStyle
            venues[index].price = venue.price
            venues[index].note = venue.note
            venues[index].companions = venue.companions
            selectedVenue = venues[index]
        } else {
            venues.append(venue)
            selectedVenue = venue
        }
    }

    func update(_ venue: MartiniVenue) {
        guard let index = venues.firstIndex(where: {
            if let ratingID = venue.backendRatingID {
                return $0.backendRatingID == ratingID
            }
            return $0.id == venue.id || (
                $0.name.localizedCaseInsensitiveCompare(venue.name) == .orderedSame &&
                $0.location.localizedCaseInsensitiveCompare(venue.location) == .orderedSame
            )
        }) else { return }
        venues[index] = venue
        selectedVenue = venue
    }

    func syncFromBackend(_ rows: [TinisLeaderboardRow]) {
        guard !rows.isEmpty else { return }
        venues = rows.map { row in
            let location = [row.city, row.region]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            let dirty = (row.dirtiness ?? 2) >= 3 ? "dirty" : "clean"
            let cold = (row.chilliness ?? 2) >= 3 ? "very cold" : "soft"
            return MartiniVenue(
                name: row.venueName,
                location: location,
                score: row.score,
                ratingCount: row.ratingCount,
                date: displayDate(row.latestVisit),
                trait: "\(cold), \(dirty)",
                dirtiness: row.dirtiness ?? 2,
                chilliness: row.chilliness ?? 2,
                uniqueness: row.uniqueness ?? 2,
                spiritForward: row.spiritForward ?? 2,
                elo: 1500,
                spirit: row.spirit?.capitalized ?? "Unknown",
                garnish: row.garnish?.capitalized ?? "Unknown",
                servingStyle: row.servingStyle?.capitalized ?? "Unknown",
                price: row.price,
                note: row.publicNote ?? "",
                companions: row.companions ?? [],
                backendRatingID: row.ratingID,
                ratingOwnerID: row.ratingUserID,
                isOwnRating: row.isOwnRating ?? false,
                visitedAt: row.latestVisit
            )
        }
    }

    private func displayDate(_ timestamp: String) -> String {
        let rawDate = String(timestamp.prefix(10))
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: rawDate) else { return "Recent visit" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Theme

enum TinisColor {
    static let forest = Color(hex: 0x063C2E)
    static let deepForest = Color(hex: 0x00271D)
    static let darkestForest = Color(hex: 0x001A13)
    static let cream = Color(hex: 0xF6EFDF)
    static let paper = Color(hex: 0xEDE2CD)
    static let softWhite = Color(hex: 0xFAF4E8)
    static let ink = Color(hex: 0x17231E)
    static let gold = Color(hex: 0xC9AE72)
    static let paleGold = Color(hex: 0xE4D1A3)
    static let blush = Color(hex: 0xDDAEA7)
    static let moss = Color(hex: 0x718155)
    static let line = Color(hex: 0xD4C2A2)
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

struct ProfileAvatarView: View {
    let name: String
    var imageData: Data? = nil
    var imageURL: URL? = nil
    var size: CGFloat = 88
    var fallbackColor: Color? = nil
    var borderColor: Color = TinisColor.gold.opacity(0.65)

    private var localImage: UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        Group {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let imageURL {
                AsyncImage(url: imageURL, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(borderColor, lineWidth: 1.5))
        .accessibilityLabel("Profile photo for \(name)")
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xD75462), Color(hex: 0xD28B3B)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let fallbackColor {
                Circle().fill(fallbackColor)
            }
            Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .medium, design: .serif))
                .foregroundStyle(.white)
        }
    }
}

struct TinisRootView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend

    var body: some View {
        Group {
            if backend.isConfigured {
                if backend.phase == .ready {
                    MainTabView()
                } else {
                    TinisAuthGateView()
                }
            } else if app.hasOnboarded {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .onChange(of: backend.leaderboard, initial: true) { _, rows in
            app.syncFromBackend(rows)
        }
        .onChange(of: backend.currentDisplayName, initial: true) { _, displayName in
            if let displayName, !displayName.isEmpty {
                app.firstName = displayName
            }
        }
    }
}

struct OliveMark: View {
    var body: some View {
        ZStack {
            Circle().stroke(TinisColor.gold, lineWidth: 1.5).frame(width: 46, height: 46)
            Circle().fill(TinisColor.moss).frame(width: 15, height: 15).offset(x: -5, y: 2)
            Circle().stroke(TinisColor.cream.opacity(0.85), lineWidth: 1.2).frame(width: 4, height: 4).offset(x: -5, y: 2)
            Rectangle().fill(TinisColor.gold).frame(width: 2, height: 34).rotationEffect(.degrees(38)).offset(x: 10, y: -12)
        }
        .accessibilityLabel("tini's olive mark")
    }
}

struct MartiniBowl: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.minY + rect.height * 0.36),
            control2: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.maxY - rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.maxY - rect.height * 0.08),
            control2: CGPoint(x: rect.maxX - rect.width * 0.13, y: rect.minY + rect.height * 0.36)
        )
        path.closeSubpath()
        return path
    }
}

struct MartiniArtwork: View {
    var variant = 0
    var showOlives = true

    var body: some View {
        GeometryReader { geo in
            let isWideCard = geo.size.width / max(geo.size.height, 1) > 1.45

            ZStack {
                TinisColor.deepForest
                Image("MartiniLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: isWideCard ? min(geo.size.width, geo.size.height * 1.95) : geo.size.width,
                        height: isWideCard ? geo.size.height * 1.95 : geo.size.height
                    )
                    .offset(y: isWideCard ? geo.size.height * 0.28 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var app: TinisStore

    var body: some View {
        ZStack {
            LinearGradient(colors: [TinisColor.darkestForest, TinisColor.deepForest, TinisColor.forest], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            MartiniArtwork(variant: 1)
                .frame(height: 510)
                .opacity(0.94)
                .mask(LinearGradient(colors: [.clear, .white, .white], startPoint: .top, endPoint: .bottom))
                .offset(y: 225)
                .ignoresSafeArea()
            LinearGradient(colors: [TinisColor.darkestForest.opacity(0.95), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 58)
                OliveMark()
                    .scaleEffect(1.15)
                    .padding(.bottom, 26)
                Text("tini’s")
                    .font(.system(size: 58, weight: .light, design: .serif))
                    .foregroundStyle(TinisColor.cream)
                    .kerning(-1.5)
                    .padding(.bottom, 13)
                Text("A MARTINI RATING CLUB")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(3.5)
                    .foregroundStyle(TinisColor.gold)
                Capsule().fill(TinisColor.gold).frame(width: 28, height: 1).padding(.vertical, 24)
                Text("The dirtier, the better.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TinisColor.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer()
                Button {
                    app.hasOnboarded = true
                } label: {
                    Text("Enter the club")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(TinisColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 9))
                        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
                }
                Text("Private · Invite-only · Friends only")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(TinisColor.cream.opacity(0.68))
                    .padding(.top, 17)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 30)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var app: TinisStore

    var body: some View {
        TabView(selection: $app.selectedTab) {
            HomeView()
                .tag(0)
            SearchView()
                .tag(1)
            AddMartiniView()
                .tag(2)
            RankingsView()
                .tag(3)
            ProfileView()
                .tag(4)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TinisTabBar(selection: $app.selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct TinisTabBar: View {
    @Binding var selection: Int
    private let items = [
        ("Home", "house.fill"),
        ("Search", "magnifyingglass"),
        ("Add", "plus"),
        ("Rankings", "chart.bar.fill"),
        ("Profile", "person.fill")
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    VStack(spacing: 5) {
                        if index == 2 {
                            ZStack {
                                Circle().fill(TinisColor.cream)
                                Image(systemName: items[index].1)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(TinisColor.ink)
                            }
                            .frame(width: 46, height: 46)
                            .offset(y: -7)
                            .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
                        } else {
                            Image(systemName: items[index].1)
                                .font(.system(size: 19, weight: selection == index ? .semibold : .regular))
                                .frame(height: 24)
                                .foregroundStyle(selection == index ? TinisColor.cream : TinisColor.cream.opacity(0.58))
                        }
                        Text(items[index].0)
                            .font(.system(size: 9, weight: selection == index ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(selection == index ? TinisColor.gold : TinisColor.cream.opacity(0.56))
                            .offset(y: index == 2 ? -7 : 0)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(items[index].0)
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .background(TinisColor.darkestForest)
        .overlay(alignment: .top) { Rectangle().fill(TinisColor.gold.opacity(0.22)).frame(height: 0.5) }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend
    @State private var demoCheeredIDs: Set<UUID> = []

    private let demoActivity = [
        FriendActivity(friend: "Sarah", initials: "S", venueName: "Bemelmans Bar", location: "New York, NY", score: 9.2, trait: "Very cold · lightly dirty", note: "Perfectly cold and exactly dirty enough.", time: "12 min ago", rankingUpdate: "New #1", avatarHex: 0xC85B68, artworkVariant: 0, photoURL: nil),
        FriendActivity(friend: "Alex", initials: "A", venueName: "Dante", location: "New York, NY", score: 8.4, trait: "Bright · classic", note: "A crisp one. The lemon twist really works.", time: "1 hr ago", rankingUpdate: "Moved to #2", avatarHex: 0x5A9181, artworkVariant: 1, photoURL: nil),
        FriendActivity(friend: "Maya", initials: "M", venueName: "Clover Club", location: "Brooklyn, NY", score: 8.8, trait: "Silky · olive", note: "Would immediately order another.", time: "Last night", rankingUpdate: "New entry", avatarHex: 0xA475B5, artworkVariant: 2, photoURL: nil),
        FriendActivity(friend: "Jack", initials: "J", venueName: "Employees Only", location: "New York, NY", score: 7.5, trait: "Spirit-forward · clean", note: "Strong, serious, and maybe a little too warm.", time: "Yesterday", rankingUpdate: "Now #4", avatarHex: 0xB27645, artworkVariant: 3, photoURL: nil)
    ]

    private var activity: [FriendActivity] {
        guard backend.isConfigured else {
            return demoActivity.map { item in
                var updated = item
                updated.isCheered = demoCheeredIDs.contains(item.id)
                updated.cheersCount += updated.isCheered ? 1 : 0
                return updated
            }
        }
        return backend.friendFeed.enumerated().map { index, row in
            let initial = String(row.displayName.prefix(1)).uppercased()
            let cold = (row.chilliness ?? 2) >= 3 ? "Very cold" : "Soft"
            let dirty = (row.dirtiness ?? 2) >= 3 ? "dirty" : "clean"
            let cheers = backend.cheersByRating[row.id] ?? TinisCheersState(
                count: row.cheersCount ?? 0,
                isCheered: row.cheeredByMe ?? false
            )
            return FriendActivity(
                friend: row.displayName,
                initials: initial,
                venueName: row.venueName,
                location: [row.city, row.region].filter { !$0.isEmpty }.joined(separator: ", "),
                score: row.score,
                trait: "\(cold) · \(dirty)",
                note: row.publicNote ?? "Added this martini to the club.",
                time: "Recently",
                rankingUpdate: "New rating",
                avatarHex: [0xC85B68, 0x5A9181, 0xA475B5, 0xB27645][index % 4],
                artworkVariant: index % 4,
                photoURL: backend.photoURLs[row.id],
                avatarURL: backend.avatarURLs[row.userID],
                ratingID: row.id,
                userID: row.userID,
                dirtiness: row.dirtiness ?? 2,
                chilliness: row.chilliness ?? 2,
                uniqueness: row.uniqueness ?? 2,
                spiritForward: row.spiritForward ?? 2,
                spirit: row.spirit?.capitalized ?? "Unknown",
                garnish: row.garnish?.capitalized ?? "Unknown",
                servingStyle: row.servingStyle?.capitalized ?? "Unknown",
                price: row.price,
                companions: row.companions ?? [],
                visitedAt: row.visitedAt,
                isOwnRating: backend.currentUserID == row.userID,
                cheersCount: cheers.count,
                isCheered: cheers.isCheered
            )
        }
    }

    private func detailVenue(for activity: FriendActivity) -> MartiniVenue {
        MartiniVenue(
            name: activity.venueName,
            location: activity.location,
            score: activity.score,
            ratingCount: 1,
            date: activity.time,
            trait: activity.trait,
            dirtiness: activity.dirtiness,
            chilliness: activity.chilliness,
            uniqueness: activity.uniqueness,
            spiritForward: activity.spiritForward,
            elo: TinisElo.startingRating,
            spirit: activity.spirit,
            garnish: activity.garnish,
            servingStyle: activity.servingStyle,
            price: activity.price,
            note: activity.note,
            companions: activity.companions,
            backendRatingID: activity.ratingID,
            ratingOwnerID: activity.userID,
            ratingOwnerName: activity.friend,
            isOwnRating: activity.isOwnRating,
            cheersCount: activity.cheersCount,
            isCheered: activity.isCheered,
            visitedAt: activity.visitedAt
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.deepForest.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Recent Pours")
                                    .font(.system(size: 29, weight: .regular, design: .serif))
                                    .kerning(-0.4)
                                Text("What your friends are rating")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(TinisColor.cream.opacity(0.72))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 10) {
                                AvatarStack()
                                Image(systemName: "bell")
                                    .font(.system(size: 15))
                                    .foregroundStyle(TinisColor.gold)
                            }
                        }
                        .foregroundStyle(TinisColor.cream)

                        HStack {
                            Text("THE CLUB")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.3)
                                .foregroundStyle(TinisColor.gold)
                            Spacer()
                            Label("Everyone", systemImage: "chevron.down")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(TinisColor.cream.opacity(0.68))
                        }

                        if backend.isConfigured && activity.isEmpty {
                            VStack(spacing: 13) {
                                OliveMark()
                                    .scaleEffect(0.72)
                                    .frame(height: 44)
                                Text("No pours yet")
                                    .font(.system(size: 24, design: .serif))
                                Text("Be the first to rate a martini. Your friends’ ratings will appear here as they join in.")
                                    .font(.system(size: 12, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(TinisColor.cream.opacity(0.66))
                                    .lineSpacing(3)
                            }
                            .foregroundStyle(TinisColor.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 42)
                            .background(TinisColor.darkestForest.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TinisColor.gold.opacity(0.22)))
                        } else {
                            ForEach(activity) { item in
                                FriendActivityCard(
                                    activity: item,
                                    action: { app.selectedVenue = detailVenue(for: item) },
                                    cheersAction: {
                                        if let ratingID = item.ratingID {
                                            Task { await backend.toggleCheers(for: ratingID) }
                                        } else if demoCheeredIDs.contains(item.id) {
                                            demoCheeredIDs.remove(item.id)
                                        } else {
                                            demoCheeredIDs.insert(item.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                }
            }
            .sheet(item: $app.selectedVenue) {
                VenueDetailView(venue: $0)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct FriendActivityCard: View {
    let activity: FriendActivity
    let action: () -> Void
    let cheersAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    ProfileAvatarView(
                        name: activity.friend,
                        imageURL: activity.avatarURL,
                        size: 38,
                        fallbackColor: Color(hex: activity.avatarHex),
                        borderColor: TinisColor.gold.opacity(0.42)
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.friend)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("rated a martini · \(activity.time)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(TinisColor.ink.opacity(0.48))
                    }
                    Spacer()
                    ScoreBadge(score: activity.score)
                }

                ZStack(alignment: .bottomLeading) {
                    FriendActivityArtwork(activity: activity)
                        .frame(height: 145)
                    LinearGradient(colors: [.clear, Color.black.opacity(0.82)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.venueName)
                            .font(.system(size: 20, design: .serif))
                        Text(activity.location)
                            .font(.system(size: 10, design: .rounded))
                            .opacity(0.72)
                    }
                    .foregroundStyle(TinisColor.cream)
                    .padding(13)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))

                HStack(spacing: 8) {
                    Text(activity.rankingUpdate)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(TinisColor.cream)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TinisColor.forest, in: Capsule())
                    Text(activity.trait)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(TinisColor.moss)
                        .lineLimit(1)
                }

                Text("“\(activity.note)”")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(TinisColor.ink.opacity(0.78))
                    .lineSpacing(2)
                }
                .foregroundStyle(TinisColor.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(activity.friend) rated \(activity.venueName) \(activity.score, format: .number.precision(.fractionLength(1))). \(activity.rankingUpdate)")

            Divider().overlay(TinisColor.line.opacity(0.8))

            HStack {
                if activity.isOwnRating {
                    Label("Your rating", systemImage: "pencil")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(TinisColor.moss)
                } else {
                    Button(action: cheersAction) {
                        HStack(spacing: 6) {
                            Text("🍸")
                            Text("Cheers")
                            if activity.cheersCount > 0 {
                                Text("\(activity.cheersCount)")
                                    .monospacedDigit()
                            }
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(activity.isCheered ? TinisColor.cream : TinisColor.forest)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(activity.isCheered ? TinisColor.forest : TinisColor.paleGold.opacity(0.38), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(activity.isCheered ? "Remove cheers" : "Cheers this rating")
                }
                Spacer()
                Button(action: action) {
                    Label("Details", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(TinisColor.ink.opacity(0.48))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(TinisColor.gold.opacity(0.28)))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }
}

struct FriendActivityArtwork: View {
    let activity: FriendActivity

    var body: some View {
        Group {
            if let photoURL = activity.photoURL {
                AsyncImage(url: photoURL, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        MartiniArtwork(variant: activity.artworkVariant)
                    }
                }
            } else {
                MartiniArtwork(variant: activity.artworkVariant)
            }
        }
        .clipped()
        .accessibilityLabel(activity.photoURL == nil ? "Martini illustration" : "Photo of the martini")
    }
}

struct AvatarStack: View {
    private let colors: [Color] = [.pink.opacity(0.8), .orange.opacity(0.8), .mint, .purple.opacity(0.75)]
    var body: some View {
        HStack(spacing: -8) {
            ForEach(colors.indices, id: \.self) { index in
                let color = colors[index]
                Circle()
                    .fill(color)
                    .frame(width: 27, height: 27)
                    .overlay(Text(["V", "S", "A", "M"][index]).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.white))
                    .overlay(Circle().stroke(TinisColor.darkestForest, lineWidth: 2))
            }
        }
    }
}

struct VenueRow: View {
    let rank: Int
    let venue: MartiniVenue
    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .medium, design: .serif).monospacedDigit())
                .frame(width: 17)
            VenueThumbnail(index: rank)
            VStack(alignment: .leading, spacing: 4) {
                Text(venue.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(TinisColor.ink)
                Text(venue.location).font(.system(size: 11, design: .rounded)).foregroundStyle(TinisColor.ink.opacity(0.55))
                Text("\(venue.ratingCount) friend ratings · \(venue.trait)")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(TinisColor.moss)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                ScoreBadge(score: venue.score)
                Text(venue.date).font(.system(size: 9, design: .rounded)).foregroundStyle(TinisColor.ink.opacity(0.48))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(TinisColor.cream)
        .contentShape(Rectangle())
    }
}

struct VenueThumbnail: View {
    let index: Int
    var body: some View {
        MartiniArtwork(variant: index - 1, showOlives: index != 4)
            .frame(width: 58, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.16)))
    }
}

struct ScoreBadge: View {
    let score: Double
    var body: some View {
        Text(score, format: .number.precision(.fractionLength(1)))
            .font(.system(size: 21, weight: .regular, design: .serif).monospacedDigit())
            .foregroundStyle(TinisColor.ink)
            .frame(width: 45, height: 45)
            .background(TinisColor.cream, in: Circle())
            .overlay(Circle().stroke(TinisColor.gold.opacity(0.48), lineWidth: 1))
    }
}

// MARK: - Search and Detail

struct SearchView: View {
    @EnvironmentObject private var app: TinisStore
    @State private var isShowingPlaceSearch = false
    @State private var searchNotice: String?

    var body: some View {
        ZStack {
            TinisColor.deepForest.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Find a martini")
                        .font(.system(size: 30, design: .serif))
                        .foregroundStyle(TinisColor.cream)
                    Text("Bars, restaurants, and the ones worth remembering.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(TinisColor.cream.opacity(0.64))
                }

                Button {
                    if TinisGooglePlaces.isConfigured {
                        isShowingPlaceSearch = true
                    } else {
                        searchNotice = "Google venue search is ready in the app, but it still needs a Google Places API key."
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(TinisColor.moss)
                        Text("Search bars or restaurants")
                            .foregroundStyle(TinisColor.ink.opacity(0.55))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TinisColor.forest)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)

                HStack {
                    Text("RATED BY YOUR CLUB")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(TinisColor.cream.opacity(0.58))
                    Spacer()
                    Text("\(app.venues.count) spots")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(TinisColor.gold)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(app.venues.enumerated()), id: \.element.id) { index, venue in
                            Button {
                                app.selectedVenue = venue
                            } label: {
                                HStack(spacing: 12) {
                                    VenueThumbnail(index: index + 1)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(venue.name)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        Label(venue.location, systemImage: "mappin")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(TinisColor.ink.opacity(0.52))
                                        Text(venue.trait.capitalized)
                                            .font(.system(size: 10, design: .rounded))
                                            .foregroundStyle(TinisColor.moss)
                                    }
                                    Spacer()
                                    ScoreBadge(score: venue.score)
                                }
                                .foregroundStyle(TinisColor.ink)
                                .padding(11)
                                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.gold.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .sheet(item: $app.selectedVenue) {
            VenueDetailView(venue: $0)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .tinisPlaceSearch(
            show: $isShowingPlaceSearch,
            onSelection: { selection in
                app.pendingGooglePlace = selection
                withAnimation(.easeInOut(duration: 0.25)) {
                    app.selectedTab = 2
                }
            },
            onError: { _ in
                searchNotice = "Google venue search could not load. Please check your connection and try again."
            }
        )
        .alert("Venue search", isPresented: Binding(
            get: { searchNotice != nil },
            set: { if !$0 { searchNotice = nil } }
        )) {
            Button("OK") { searchNotice = nil }
        } message: {
            Text(searchNotice ?? "")
        }
    }
}

struct VenueDetailView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend
    @Environment(\.dismiss) private var dismiss
    @State private var displayedVenue: MartiniVenue
    @State private var isEditingRating = false
    @State private var isUpdatingCheers = false

    init(venue: MartiniVenue) {
        _displayedVenue = State(initialValue: venue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack(alignment: .bottomLeading) {
                        MartiniArtwork(variant: abs(displayedVenue.name.hashValue) % 4)
                            .frame(height: 285)
                        LinearGradient(colors: [.clear, Color.black.opacity(0.84)], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayedVenue.name)
                                .font(.system(size: 30, design: .serif))
                            Text(displayedVenue.location)
                                .font(.system(size: 12, design: .rounded))
                                .opacity(0.74)
                        }
                        .foregroundStyle(TinisColor.cream)
                        .padding(19)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(TinisColor.gold.opacity(0.28)))

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(displayedVenue.isOwnRating ? "YOUR LATEST RATING" : "\((displayedVenue.ratingOwnerName ?? "FRIEND").uppercased())’S RATING")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(TinisColor.moss)
                            Text(displayedVenue.date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ScoreBadge(score: displayedVenue.score)
                    }

                    if !displayedVenue.isOwnRating {
                        Button {
                            guard !isUpdatingCheers else { return }
                            isUpdatingCheers = true
                            displayedVenue.isCheered.toggle()
                            displayedVenue.cheersCount = max(0, displayedVenue.cheersCount + (displayedVenue.isCheered ? 1 : -1))
                            Task {
                                if let ratingID = displayedVenue.backendRatingID {
                                    await backend.toggleCheers(for: ratingID)
                                    if let refreshed = backend.cheersByRating[ratingID] {
                                        displayedVenue.isCheered = refreshed.isCheered
                                        displayedVenue.cheersCount = refreshed.count
                                    }
                                }
                                isUpdatingCheers = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("🍸")
                                Text(displayedVenue.isCheered ? "Cheers’d" : "Cheers")
                                if displayedVenue.cheersCount > 0 {
                                    Text("\(displayedVenue.cheersCount)").monospacedDigit()
                                }
                                Spacer()
                                if isUpdatingCheers { ProgressView().tint(displayedVenue.isCheered ? TinisColor.cream : TinisColor.forest) }
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(displayedVenue.isCheered ? TinisColor.cream : TinisColor.forest)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(displayedVenue.isCheered ? TinisColor.forest : TinisColor.paleGold.opacity(0.42), in: RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }

                    MartiniBasicsSummary(venue: displayedVenue)

                    RatingOccasionSummary(venue: displayedVenue)

                    InfoCard(title: "TASTING NOTES") {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TinisColor.gold)
                            Text(displayedVenue.note.isEmpty ? "No notes added for this martini." : displayedVenue.note)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(displayedVenue.note.isEmpty ? TinisColor.ink.opacity(0.48) : TinisColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    TraitSummary(venue: displayedVenue)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("FRIEND RATINGS").font(.caption.bold()).tracking(1.2)
                        HStack(spacing: 17) {
                            FriendScore(name: displayedVenue.isOwnRating ? "You" : (displayedVenue.ratingOwnerName ?? "Friend"), score: displayedVenue.score, color: TinisColor.moss)
                            FriendScore(name: "Sarah", score: 9.2, color: .pink.opacity(0.7))
                            FriendScore(name: "Alex", score: 8.0, color: .purple.opacity(0.7))
                            FriendScore(name: "Maya", score: 8.6, color: .orange.opacity(0.7))
                        }
                    }
                }
                .padding(20)
            }
            .background(TinisColor.cream)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if displayedVenue.isOwnRating {
                        Button {
                            isEditingRating = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(TinisColor.forest)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(TinisColor.forest)
                }
            }
            .sheet(isPresented: $isEditingRating) {
                EditRatingView(venue: displayedVenue) { updatedVenue in
                    displayedVenue = updatedVenue
                    app.update(updatedVenue)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct EditRatingView: View {
    @EnvironmentObject private var backend: TinisBackend
    @Environment(\.dismiss) private var dismiss

    let venue: MartiniVenue
    let onSave: (MartiniVenue) -> Void

    @State private var spirit: String
    @State private var garnish: String
    @State private var servingStyle: String
    @State private var price: String
    @State private var note: String
    @State private var visitDate: Date
    @State private var traits: [String: Double]
    @State private var selectedCompanionIDs: Set<UUID> = []
    @State private var didLoadCompanions = false
    @State private var isSaving = false
    @State private var saveError: String?

    init(venue: MartiniVenue, onSave: @escaping (MartiniVenue) -> Void) {
        self.venue = venue
        self.onSave = onSave
        _spirit = State(initialValue: venue.spirit)
        _garnish = State(initialValue: venue.garnish)
        _servingStyle = State(initialValue: venue.servingStyle)
        _price = State(initialValue: venue.price.map { value in
            value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
        } ?? "")
        _note = State(initialValue: venue.note)
        _visitDate = State(initialValue: Self.parseDate(venue.visitedAt) ?? Self.parseDisplayDate(venue.date) ?? Date())
        _traits = State(initialValue: [
            "Dirtiness": venue.dirtiness,
            "Chilliness": venue.chilliness,
            "Uniqueness": venue.uniqueness,
            "Spirit-forward": venue.spiritForward
        ])
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func parseDisplayDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["MMM d, yyyy", "MMMM d, yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private var selectedCompanionNames: [String] {
        backend.clubFriends
            .filter { selectedCompanionIDs.contains($0.id) }
            .map(\.displayName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EDIT YOUR RATING")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(TinisColor.moss)
                            Text(venue.name)
                                .font(.system(size: 28, design: .serif))
                                .foregroundStyle(TinisColor.ink)
                            Text("Your score stays ELO-based; everything below can be refined.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(TinisColor.ink.opacity(0.54))
                        }

                        InfoCard(title: "THE BASICS") {
                            OptionPills(label: "Spirit", options: ["Gin", "Vodka", "Both", "Unknown"], selection: $spirit)
                            OptionPills(label: "Garnish", options: ["Olive", "Lemon", "Onion", "Other"], selection: $garnish)
                            OptionPills(label: "Serve", options: ["Up", "Rocks", "Other"], selection: $servingStyle)
                            Divider()
                            HStack {
                                Text("Price").font(.system(size: 12, weight: .medium, design: .rounded))
                                Spacer()
                                Text("$").foregroundStyle(TinisColor.moss)
                                TextField("19", text: $price)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 64)
                            }
                            Divider()
                            DatePicker("Date", selection: $visitDate, in: ...Date(), displayedComponents: .date)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("TRAITS")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(TinisColor.moss)
                            TraitEditorRow(title: "Dirtiness", low: "Clean", high: "Filthy", symbol: "olive", value: traitBinding("Dirtiness"))
                            TraitEditorRow(title: "Chilliness", low: "Warm", high: "Arctic", symbol: "snowflake", value: traitBinding("Chilliness"))
                            TraitEditorRow(title: "Uniqueness", low: "Classic", high: "Wild", symbol: "sparkles", value: traitBinding("Uniqueness"))
                            TraitEditorRow(title: "Spirit-forward", low: "Smooth", high: "Rocket fuel", symbol: "martini", value: traitBinding("Spirit-forward"))
                        }

                        InfoCard(title: "TASTING NOTES") {
                            TextField("What stood out?", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                                .onChange(of: note) { _, newValue in
                                    if newValue.count > 500 { note = String(newValue.prefix(500)) }
                                }
                            Text("\(note.count)/500")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(TinisColor.ink.opacity(0.42))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if !backend.clubFriends.isEmpty {
                            InfoCard(title: "WHO WERE YOU WITH?") {
                                FlowLayout(spacing: 8) {
                                    ForEach(backend.clubFriends) { friend in
                                        let isSelected = selectedCompanionIDs.contains(friend.id)
                                        Button {
                                            if isSelected { selectedCompanionIDs.remove(friend.id) }
                                            else { selectedCompanionIDs.insert(friend.id) }
                                        } label: {
                                            Label(friend.displayName, systemImage: isSelected ? "checkmark.circle.fill" : "person.crop.circle")
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundStyle(isSelected ? TinisColor.cream : TinisColor.forest)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? TinisColor.forest : TinisColor.paleGold.opacity(0.28), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        if let saveError {
                            Text(saveError)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color(hex: 0xA54F45))
                        }

                        Button {
                            saveRating()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving { ProgressView().tint(TinisColor.cream) }
                                Text(isSaving ? "Saving changes…" : "Save changes")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(TinisColor.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(TinisColor.forest, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Edit rating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TinisColor.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TinisColor.forest)
                }
            }
            .onAppear {
                guard !didLoadCompanions else { return }
                selectedCompanionIDs = Set(backend.clubFriends
                    .filter { venue.companions.contains($0.displayName) }
                    .map(\.id))
                didLoadCompanions = true
            }
        }
    }

    private func traitBinding(_ key: String) -> Binding<Double> {
        Binding(get: { traits[key] ?? 2 }, set: { traits[key] = $0 })
    }

    private func saveRating() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil

        var updated = venue
        updated.spirit = spirit
        updated.garnish = garnish
        updated.servingStyle = servingStyle
        updated.price = Double(price)
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.dirtiness = traits["Dirtiness"] ?? 2
        updated.chilliness = traits["Chilliness"] ?? 2
        updated.uniqueness = traits["Uniqueness"] ?? 2
        updated.spiritForward = traits["Spirit-forward"] ?? 2
        updated.date = visitDate.formatted(date: .abbreviated, time: .omitted)
        updated.visitedAt = ISO8601DateFormatter().string(from: visitDate)
        updated.companions = selectedCompanionNames.isEmpty && backend.clubFriends.isEmpty
            ? venue.companions
            : selectedCompanionNames
        updated.trait = "\(updated.chilliness >= 3 ? "very cold" : "soft"), \(updated.dirtiness >= 3 ? "dirty" : "clean")"

        Task {
            let didSave: Bool
            if let ratingID = venue.backendRatingID {
                didSave = await backend.updateRating(
                    id: ratingID,
                    venue: updated,
                    visitDate: visitDate,
                    companionIDs: Array(selectedCompanionIDs)
                )
            } else {
                didSave = true
            }

            if didSave {
                onSave(updated)
                dismiss()
            } else {
                saveError = backend.errorMessage ?? "Your rating could not be updated."
                isSaving = false
            }
        }
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(TinisColor.ink.opacity(0.56))
            content
        }
        .foregroundStyle(TinisColor.ink)
        .padding(16)
        .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.line.opacity(0.9)))
        .shadow(color: TinisColor.ink.opacity(0.035), radius: 10, y: 4)
    }
}

struct TraitSummary: View {
    let venue: MartiniVenue

    private var rows: [(String, String, String, Int, String)] {
        [
            ("Dirtiness", "Clean", "Filthy", step(for: venue.dirtiness), "olive"),
            ("Chilliness", "Warm", "Arctic", step(for: venue.chilliness), "snowflake"),
            ("Uniqueness", "Classic", "Wild", step(for: venue.uniqueness), "sparkles"),
            ("Spirit-forward", "Smooth", "Rocket fuel", step(for: venue.spiritForward), "martini")
        ]
    }

    private func step(for value: Double) -> Int {
        min(4, max(0, Int(value.rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("TRAITS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2)
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                VStack(spacing: 7) {
                    HStack {
                        Text(row.0).font(.system(size: 12, weight: .medium, design: .rounded))
                        Spacer()
                        Text("\(row.1)  —  \(row.2)").font(.system(size: 10, design: .rounded)).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(TinisColor.ink.opacity(0.14)).frame(height: 1)
                            HStack {
                                ForEach(0..<5, id: \.self) { step in
                                    TraitGlyph(
                                        symbol: row.4,
                                        step: step,
                                        active: step <= row.3,
                                        size: 10 + CGFloat(step)
                                    )
                                    if step < 4 { Spacer() }
                                }
                            }
                        }
                    }.frame(height: 16)
                }
            }
        }
    }
}

struct MartiniBasicsSummary: View {
    let venue: MartiniVenue

    private var priceText: String {
        guard let price = venue.price else { return "—" }
        return price.formatted(
            .currency(code: "USD")
                .precision(.fractionLength(price.rounded() == price ? 0 : 2))
        )
    }

    var body: some View {
        InfoCard(title: "THE BASICS") {
            HStack(spacing: 0) {
                BasicRatingValue(label: "SPIRIT", value: venue.spirit)
                Divider().frame(height: 38)
                BasicRatingValue(label: "GARNISH", value: venue.garnish)
                Divider().frame(height: 38)
                BasicRatingValue(label: "SERVE", value: venue.servingStyle)
                Divider().frame(height: 38)
                BasicRatingValue(label: "PRICE", value: priceText)
            }
        }
    }
}

struct BasicRatingValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(TinisColor.ink.opacity(0.48))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(TinisColor.forest)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
    }
}

struct RatingOccasionSummary: View {
    let venue: MartiniVenue

    var body: some View {
        InfoCard(title: "THE OCCASION") {
            HStack {
                Label(venue.date, systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TinisColor.forest)
                Spacer()
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("WITH")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(TinisColor.ink.opacity(0.48))
                if venue.companions.isEmpty {
                    Text("Just me")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(TinisColor.ink.opacity(0.52))
                } else {
                    FlowLayout(spacing: 7) {
                        ForEach(venue.companions, id: \.self) { friend in
                            Label(friend, systemImage: "person.fill")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(TinisColor.forest)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(TinisColor.paleGold.opacity(0.38), in: Capsule())
                        }
                    }
                }
            }
        }
    }
}

struct FriendScore: View {
    let name: String
    let score: Double
    let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Circle().fill(color).frame(width: 38, height: 38).overlay(Text(String(name.prefix(1))).foregroundStyle(.white).font(.caption.bold()))
            Text(name).font(.caption2)
            Text(score, format: .number.precision(.fractionLength(1))).font(.headline.monospacedDigit())
        }
    }
}

// MARK: - Add flow

struct AddMartiniView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend
    @State private var stage = 0
    @State private var venueName = ""
    @State private var location = "New York, NY"
    @State private var price = "19"
    @State private var spirit = "Gin"
    @State private var garnish = "Olive"
    @State private var servingStyle = "Up"
    @State private var note = ""
    @State private var visitDate = Date()
    @State private var selectedCompanionIDs: Set<UUID> = []
    @State private var photoData: Data?
    @State private var traits = ["Dirtiness": 3.0, "Chilliness": 4.0, "Uniqueness": 2.0, "Spirit-forward": 4.0]
    @State private var duelChoice: DuelChoice?
    @State private var isSaving = false
    @State private var saveNotice: String?
    @State private var didSaveDespiteNotice = false
    @State private var isShowingPlaceSearch = false
    @State private var placeSearchNotice: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [TinisColor.cream, TinisColor.paper.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ProgressLine(stage: stage)
                        if stage == 0 {
                            BasicsStep(
                                venueName: $venueName,
                                location: $location,
                                price: $price,
                                spirit: $spirit,
                                garnish: $garnish,
                                servingStyle: $servingStyle,
                                note: $note,
                                visitDate: $visitDate,
                                friends: availableFriends,
                                selectedCompanionIDs: $selectedCompanionIDs,
                                photoData: $photoData,
                                searchVenue: openVenueSearch
                            )
                        }
                        if stage == 1 { TraitsStep(traits: $traits, spirit: spirit, garnish: garnish, servingStyle: servingStyle) }
                        if stage == 2 {
                            if let comparison = rankingComparison {
                                DuelStep(
                                    comparison: comparison,
                                    choice: $duelChoice,
                                    newTitle: existingRankedVenue?.name ?? "The new martini",
                                    newSubtitle: existingRankedVenue == nil ? "Unranked" : "Your updated pour",
                                    comparisonSubtitle: existingRankedVenue == nil ? "Your current #1" : "Another favorite"
                                )
                            } else {
                                FirstRankingStep()
                            }
                        }
                        Button {
                            if stage < 2 { stage += 1 } else {
                                guard !isSaving else { return }
                                isSaving = true
                                let existingVenue = existingRankedVenue
                                let comparison = rankingComparison
                                let startingElo = existingVenue?.elo ?? TinisElo.startingRating
                                let updatedElo: (new: Int, past: Int)
                                if let comparison {
                                    updatedElo = TinisElo.updatedRatings(
                                        newRating: startingElo,
                                        pastRating: comparison.elo,
                                        choice: duelChoice
                                    )
                                } else {
                                    updatedElo = (startingElo, startingElo)
                                }
                                let newVenue = MartiniVenue(
                                    name: venueName.isEmpty ? "A very good martini" : venueName,
                                    location: location,
                                    score: TinisElo.displayScore(for: updatedElo.new),
                                    ratingCount: 1,
                                    date: "Today",
                                    trait: traitDescription,
                                    dirtiness: traits["Dirtiness"] ?? 2,
                                    chilliness: traits["Chilliness"] ?? 2,
                                    uniqueness: traits["Uniqueness"] ?? 2,
                                    spiritForward: traits["Spirit-forward"] ?? 2,
                                    elo: updatedElo.new,
                                    spirit: spirit,
                                    garnish: garnish,
                                    servingStyle: servingStyle,
                                    price: Double(price),
                                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                    companions: availableFriends
                                        .filter { selectedCompanionIDs.contains($0.id) }
                                        .map(\.displayName)
                                )
                                Task {
                                    do {
                                        if backend.isReady {
                                            let photoWarning = try await backend.saveRating(
                                                newVenue,
                                                price: price,
                                                spirit: spirit,
                                                garnish: garnish,
                                                servingStyle: servingStyle,
                                                visitDate: visitDate,
                                                companionIDs: Array(selectedCompanionIDs),
                                                photoData: photoData
                                            )
                                            if let photoWarning {
                                                if let comparison {
                                                    app.updateElo(for: comparison, to: updatedElo.past)
                                                }
                                                app.add(newVenue)
                                                resetForm()
                                                didSaveDespiteNotice = true
                                                saveNotice = photoWarning
                                                return
                                            }
                                        }
                                        if let comparison {
                                            app.updateElo(for: comparison, to: updatedElo.past)
                                        }
                                        app.add(newVenue)
                                        resetForm()
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            app.selectedTab = 3
                                        }
                                    } catch {
                                        didSaveDespiteNotice = false
                                        saveNotice = "Your martini could not be saved. Please try again."
                                        isSaving = false
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 9) {
                                if isSaving { ProgressView().tint(.white) }
                                Text(isSaving ? (photoData == nil ? "Saving martini…" : "Uploading photo…") : stage == 2 ? "Save martini" : stage == 1 ? "Next: quick ranking" : "Next: traits & details")
                            }
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                                .padding(.vertical, 17)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(colors: [TinisColor.forest, TinisColor.deepForest], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .shadow(color: TinisColor.forest.opacity(0.22), radius: 12, y: 5)
                        }
                        .disabled(isSaving)
                    }
                    .padding(20)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle(stage == 0 ? "Add a Martini" : stage == 1 ? "Traits & Details" : "One quick question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .preferredColorScheme(.light)
            .alert(didSaveDespiteNotice ? "Rating saved" : "Couldn’t save martini", isPresented: Binding(
                get: { saveNotice != nil },
                set: { if !$0 { saveNotice = nil } }
            )) {
                Button(didSaveDespiteNotice ? "View rankings" : "OK") {
                    saveNotice = nil
                    if didSaveDespiteNotice {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            app.selectedTab = 3
                        }
                    }
                }
            } message: {
                Text(saveNotice ?? "")
            }
            .tinisPlaceSearch(
                show: $isShowingPlaceSearch,
                initialQuery: venueName,
                onSelection: applyGooglePlace,
                onError: { _ in
                    placeSearchNotice = "Google venue search could not load. Please check your connection and try again."
                }
            )
            .alert("Venue search", isPresented: Binding(
                get: { placeSearchNotice != nil },
                set: { if !$0 { placeSearchNotice = nil } }
            )) {
                Button("OK") { placeSearchNotice = nil }
            } message: {
                Text(placeSearchNotice ?? "")
            }
            .onAppear(perform: applyPendingGooglePlace)
            .onChange(of: app.pendingGooglePlace) { _, _ in applyPendingGooglePlace() }
        }
    }

    private func openVenueSearch() {
        if TinisGooglePlaces.isConfigured {
            isShowingPlaceSearch = true
        } else {
            placeSearchNotice = "Google venue search is ready in the app, but it still needs a Google Places API key."
        }
    }

    private func applyPendingGooglePlace() {
        guard let selection = app.pendingGooglePlace else { return }
        applyGooglePlace(selection)
        app.pendingGooglePlace = nil
    }

    private func applyGooglePlace(_ selection: GooglePlaceSelection) {
        venueName = selection.name
        location = selection.location
    }

    private func resetForm() {
        stage = 0
        venueName = ""
        location = "New York, NY"
        price = "19"
        spirit = "Gin"
        garnish = "Olive"
        servingStyle = "Up"
        note = ""
        visitDate = Date()
        selectedCompanionIDs = []
        photoData = nil
        traits = ["Dirtiness": 3.0, "Chilliness": 4.0, "Uniqueness": 2.0, "Spirit-forward": 4.0]
        duelChoice = nil
        isSaving = false
    }

    private var traitDescription: String {
        let dirty = (traits["Dirtiness"] ?? 0) >= 3 ? "lightly dirty" : "clean"
        let cold = (traits["Chilliness"] ?? 0) >= 3 ? "very cold" : "soft"
        return "\(cold), \(dirty)"
    }

    private var existingRankedVenue: MartiniVenue? {
        app.existingVenue(named: venueName, location: location)
    }

    private var rankingComparison: MartiniVenue? {
        app.topVenue(excluding: existingRankedVenue)
    }

    private var availableFriends: [TinisClubFriend] {
        if !backend.clubFriends.isEmpty { return backend.clubFriends }
        return [
            TinisClubFriend(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, displayName: "Sarah"),
            TinisClubFriend(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, displayName: "Alex"),
            TinisClubFriend(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, displayName: "Maya"),
            TinisClubFriend(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, displayName: "Jack")
        ]
    }
}

struct ProgressLine: View {
    let stage: Int
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                Circle().fill(index <= stage ? TinisColor.forest : TinisColor.ink.opacity(0.18)).frame(width: 8, height: 8)
                if index < 2 { Rectangle().fill(index < stage ? TinisColor.forest : TinisColor.ink.opacity(0.18)).frame(height: 1) }
            }
        }
        .padding(.horizontal, 48)
    }
}

struct BasicsStep: View {
    @Binding var venueName: String
    @Binding var location: String
    @Binding var price: String
    @Binding var spirit: String
    @Binding var garnish: String
    @Binding var servingStyle: String
    @Binding var note: String
    @Binding var visitDate: Date
    let friends: [TinisClubFriend]
    @Binding var selectedCompanionIDs: Set<UUID>
    @Binding var photoData: Data?
    let searchVenue: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MartiniPhotoPicker(photoData: $photoData)
            InfoCard(title: "WHERE WERE YOU?") {
                Button(action: searchVenue) {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(TinisColor.moss)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(venueName.isEmpty ? "Search a bar or restaurant" : venueName)
                                .foregroundStyle(venueName.isEmpty ? TinisColor.ink.opacity(0.48) : TinisColor.ink)
                            if !venueName.isEmpty {
                                Text("Tap to change venue")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(TinisColor.moss)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(TinisColor.ink.opacity(0.28))
                    }
                }
                .buttonStyle(.plain)
                Divider()
                HStack {
                    Image(systemName: "building.2").foregroundStyle(TinisColor.moss)
                    TextField("City", text: $location).textInputAutocapitalization(.words)
                }
            }
            VStack(alignment: .leading, spacing: 15) {
                Text("THE BASICS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(TinisColor.ink.opacity(0.58))
                OptionPills(label: "Spirit", options: ["Gin", "Vodka", "Both", "Unknown"], selection: $spirit)
                OptionPills(label: "Garnish", options: ["Olive", "Lemon", "Onion", "Other"], selection: $garnish)
                OptionPills(label: "Serve", options: ["Up", "Rocks", "Other"], selection: $servingStyle)
                HStack {
                    Text("Price").font(.system(size: 12, weight: .medium, design: .rounded))
                    Spacer()
                    Text("$").foregroundStyle(TinisColor.moss)
                    TextField("19", text: $price)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 48)
                }
                Divider()
                DatePicker("Date", selection: $visitDate, in: ...Date(), displayedComponents: .date)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .padding(15)
            .background(TinisColor.softWhite.opacity(0.78), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.line.opacity(0.9)))
            InfoCard(title: "TASTING NOTES · OPTIONAL") {
                TextField("What stood out about this martini?", text: $note, axis: .vertical)
                    .font(.system(size: 14, design: .rounded))
                    .lineLimit(3...6)
                    .onChange(of: note) { _, newValue in
                        if newValue.count > 500 {
                            note = String(newValue.prefix(500))
                        }
                    }
                HStack {
                    Text("Add anything you’ll want to remember.")
                    Spacer()
                    Text("\(note.count)/500")
                }
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(TinisColor.ink.opacity(0.42))
            }
            InfoCard(title: "WHO WERE YOU WITH? · OPTIONAL") {
                FlowLayout(spacing: 8) {
                    ForEach(friends) { friend in
                        let isSelected = selectedCompanionIDs.contains(friend.id)
                        Button {
                            if isSelected {
                                selectedCompanionIDs.remove(friend.id)
                            } else {
                                selectedCompanionIDs.insert(friend.id)
                            }
                        } label: {
                            Label(friend.displayName, systemImage: isSelected ? "checkmark.circle.fill" : "person.crop.circle")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? TinisColor.cream : TinisColor.forest)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(isSelected ? TinisColor.forest : TinisColor.paleGold.opacity(0.28), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct MartiniPhotoPicker: View {
    @Binding var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingPhotoSource = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailable = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var image: UIImage? {
        photoData.flatMap(UIImage.init(data:))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    MartiniArtwork(variant: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 215)
            .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(image == nil ? 0.48 : 0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(spacing: 10) {
                Button {
                    isShowingPhotoSource = true
                } label: {
                    Label(image == nil ? "Add a martini photo" : "Change photo", systemImage: "camera.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TinisColor.cream)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(TinisColor.forest.opacity(0.94), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose whether to take a new photo or select one from your library")

                if image != nil {
                    Button {
                        selectedItem = nil
                        photoData = nil
                        errorMessage = nil
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TinisColor.cream)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.54), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo")
                }

                Spacer()
            }
            .padding(12)

            if isLoading {
                ZStack {
                    Color.black.opacity(0.34)
                    ProgressView("Preparing photo…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
            }
        }
        .frame(height: 215)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(TinisColor.gold.opacity(0.32)))
        .overlay(alignment: .topLeading) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(TinisColor.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.red.opacity(0.78), in: Capsule())
                    .padding(10)
            }
        }
        .confirmationDialog(
            image == nil ? "Add a martini photo" : "Change photo",
            isPresented: $isShowingPhotoSource,
            titleVisibility: .visible
        ) {
            Button("Take Photo") {
                #if targetEnvironment(simulator)
                isShowingCameraUnavailable = true
                #else
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    isShowingCamera = true
                } else {
                    isShowingCameraUnavailable = true
                }
                #endif
            }
            Button("Choose from Library") {
                presentPhotoLibraryAfterDismissal()
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $isShowingPhotoLibrary, selection: $selectedItem, matching: .images)
        .fullScreenCover(isPresented: $isShowingCamera) {
            MartiniCameraPicker(isPresented: $isShowingCamera) { capturedImage in
                preparePhoto(capturedImage)
            }
            .ignoresSafeArea()
        }
        .alert("Camera isn’t available here", isPresented: $isShowingCameraUnavailable) {
            Button("Choose from Library") {
                presentPhotoLibraryAfterDismissal()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("The iOS Simulator doesn’t have a camera. Try this on your iPhone, or choose an existing photo to keep testing here.")
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    guard
                        let originalData = try await newItem.loadTransferable(type: Data.self),
                        let originalImage = UIImage(data: originalData),
                        let preparedData = originalImage.tinisUploadData()
                    else {
                        throw MartiniPhotoError.couldNotRead
                    }
                    photoData = preparedData
                } catch {
                    selectedItem = nil
                    errorMessage = "That photo could not be opened."
                }
                isLoading = false
            }
        }
    }

    private func preparePhoto(_ originalImage: UIImage) {
        isLoading = true
        errorMessage = nil
        if let preparedData = originalImage.tinisUploadData() {
            photoData = preparedData
        } else {
            errorMessage = "That photo could not be prepared."
        }
        isLoading = false
    }

    private func presentPhotoLibraryAfterDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isShowingPhotoLibrary = true
        }
    }
}

private struct MartiniCameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private var parent: MartiniCameraPicker

        init(parent: MartiniCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

private enum MartiniPhotoError: Error {
    case couldNotRead
}

private extension UIImage {
    func tinisUploadData(maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        let longestSide = max(size.width, size.height)
        let scale = min(1, maxDimension / max(longestSide, 1))
        let targetSize = CGSize(
            width: max(1, (size.width * scale).rounded()),
            height: max(1, (size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let normalizedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalizedImage.jpegData(compressionQuality: quality)
    }
}

struct OptionPills: View {
    let label: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 52, alignment: .leading)
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(.system(size: 10, weight: selection == option ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(selection == option ? TinisColor.cream : TinisColor.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selection == option ? TinisColor.forest : TinisColor.cream, in: Capsule())
                        .overlay(Capsule().stroke(selection == option ? Color.clear : TinisColor.line))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TraitsStep: View {
    @Binding var traits: [String: Double]
    let spirit: String
    let garnish: String
    let servingStyle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Optional, but this is where the personality lives.")
                .font(.system(size: 23, design: .serif))
            let items = [
                ("Dirtiness", "Clean", "Filthy", "olive"),
                ("Chilliness", "Warm", "Arctic", "snowflake"),
                ("Uniqueness", "Classic", "Wild", "sparkles"),
                ("Spirit-forward", "Smooth", "Rocket fuel", "martini")
            ]
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                TraitEditorRow(
                    title: item.0,
                    low: item.1,
                    high: item.2,
                    symbol: item.3,
                    value: Binding(get: { traits[item.0] ?? 2 }, set: { traits[item.0] = $0 })
                )
            }
            InfoCard(title: "THE BASICS") {
                Text("\(spirit) · \(garnish) · \(servingStyle)")
                    .foregroundStyle(TinisColor.forest)
                    .fontWeight(.medium)
            }
        }
    }
}

struct TraitEditorRow: View {
    let title: String
    let low: String
    let high: String
    let symbol: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(low)  —  \(high)").font(.system(size: 10, design: .rounded)).foregroundStyle(.secondary)
            }
            HStack {
                ForEach(0..<5, id: \.self) { step in
                    TraitGlyph(
                        symbol: symbol,
                        step: step,
                        active: step <= Int(value),
                        size: 11 + CGFloat(step)
                    )
                    if step < 4 { Spacer() }
                }
            }
            Slider(value: $value, in: 0...4, step: 1)
                .tint(TinisColor.forest)
        }
        .padding(15)
        .background(TinisColor.softWhite.opacity(0.74), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.line.opacity(0.9)))
    }
}

struct TraitGlyph: View {
    let symbol: String
    let step: Int
    let active: Bool
    let size: CGFloat

    var body: some View {
        Group {
            if symbol == "olive" {
                ZStack {
                    Capsule()
                        .fill(active ? TinisColor.gold : TinisColor.ink.opacity(0.20))
                        .frame(width: max(1, size * 0.16), height: size * 1.05)
                        .rotationEffect(.degrees(38))
                        .offset(x: size * 0.31, y: -size * 0.31)
                    Ellipse()
                        .fill(active ? TinisColor.moss : TinisColor.ink.opacity(0.22))
                        .frame(width: size * 0.90, height: size)
                        .overlay(
                            Circle()
                                .fill(active ? Color(hex: 0x8E4939) : TinisColor.cream.opacity(0.68))
                                .frame(width: size * 0.24)
                        )
                }
                .frame(width: size * 1.32, height: size * 1.32)
                .rotationEffect(.degrees(Double(step - 2) * 4))
            } else if symbol == "martini" {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        MartiniBowl()
                            .fill(active ? TinisColor.paleGold.opacity(0.42) : TinisColor.ink.opacity(0.10))
                        MartiniBowl()
                            .stroke(active ? TinisColor.moss : TinisColor.ink.opacity(0.24), lineWidth: max(0.8, size * 0.08))
                        Capsule()
                            .fill(active ? TinisColor.gold : TinisColor.ink.opacity(0.18))
                            .frame(width: size * 0.62, height: max(0.8, size * 0.06))
                            .rotationEffect(.degrees(-16))
                            .offset(y: size * 0.30)
                    }
                    .frame(width: size * 1.35, height: size * 0.70)
                    Capsule()
                        .fill(active ? TinisColor.moss : TinisColor.ink.opacity(0.24))
                        .frame(width: max(0.8, size * 0.07), height: size * 0.60)
                    Capsule()
                        .fill(active ? TinisColor.moss : TinisColor.ink.opacity(0.24))
                        .frame(width: size * 0.72, height: max(0.8, size * 0.07))
                }
                .frame(width: size * 1.45, height: size * 1.45)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? TinisColor.moss : TinisColor.ink.opacity(0.24))
            }
        }
        .accessibilityHidden(true)
    }
}

struct DuelStep: View {
    let comparison: MartiniVenue
    @Binding var choice: DuelChoice?
    let newTitle: String
    let newSubtitle: String
    let comparisonSubtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Which would you rather order again?")
                .font(.system(size: 27, design: .serif))
                .foregroundStyle(TinisColor.ink)
            Text("This keeps your personal rankings interesting without making every rating a chore.")
                .foregroundStyle(TinisColor.ink.opacity(0.62))
            HStack(spacing: 14) {
                DuelCard(title: newTitle, subtitle: newSubtitle, selected: choice == .new) { choice = .new }
                DuelCard(title: comparison.name, subtitle: comparisonSubtitle, selected: choice == .old) { choice = .old }
            }
            HStack {
                Button("Too close") { choice = .tie }
                    .buttonStyle(.bordered)
                    .tint(TinisColor.gold)
                    .foregroundStyle(TinisColor.ink)
                Spacer()
                Button("Skip for now") { choice = .skip }
                    .buttonStyle(.borderless)
                    .foregroundStyle(TinisColor.ink.opacity(0.62))
            }
            if let choice {
                Text(choice == .new ? "A perfect debut." : choice == .old ? "Classic still wins." : choice == .tie ? "A tie is fair." : "No ranking update.")
                    .font(.subheadline)
                    .foregroundStyle(TinisColor.forest)
            }
        }
    }
}

struct FirstRankingStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your first ranked martini")
                .font(.system(size: 27, design: .serif))
                .foregroundStyle(TinisColor.ink)
            Text("Save this one now. Your next pour will unlock a quick head-to-head comparison.")
                .foregroundStyle(TinisColor.ink.opacity(0.62))
            MartiniArtwork(variant: 1)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct DuelCard: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 26) {
                Image(systemName: "wineglass").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(TinisColor.gold)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(TinisColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(TinisColor.ink.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(15)
            .background(selected ? TinisColor.forest.opacity(0.11) : .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? TinisColor.forest : TinisColor.gold.opacity(0.32), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - Rankings and profile

enum RankingCategory: String, CaseIterable, Identifiable {
    case bestOverall = "Best Overall"
    case dirtiest = "Dirtiest"
    case bestValue = "Best Value"
    case mostUnique = "Most Unique"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .bestOverall: return "star.fill"
        case .dirtiest: return "drop.fill"
        case .bestValue: return "dollarsign.circle.fill"
        case .mostUnique: return "sparkles"
        }
    }

    var heading: String {
        switch self {
        case .bestOverall: return "YOUR PERSONAL ORDER"
        case .dirtiest: return "YOUR DIRTIEST MARTINIS"
        case .bestValue: return "BEST VALUE · RATING ÷ PRICE"
        case .mostUnique: return "YOUR MOST UNIQUE MARTINIS"
        }
    }

    func sorted(_ venues: [MartiniVenue]) -> [MartiniVenue] {
        venues.sorted { first, second in
            switch self {
            case .bestOverall:
                return first.elo > second.elo
            case .dirtiest:
                return first.dirtiness > second.dirtiness
            case .bestValue:
                let firstValue = valueScore(for: first)
                let secondValue = valueScore(for: second)
                return firstValue == secondValue ? first.score > second.score : firstValue > secondValue
            case .mostUnique:
                return first.uniqueness > second.uniqueness
            }
        }
    }

    private func valueScore(for venue: MartiniVenue) -> Double {
        guard let price = venue.price, price > 0 else { return -.infinity }
        return venue.score / price
    }

    func primaryMetric(for venue: MartiniVenue) -> String {
        switch self {
        case .bestOverall:
            return String(format: "%.1f", venue.score)
        case .dirtiest:
            return "\(min(5, max(1, Int(venue.dirtiness.rounded()) + 1)))/5"
        case .bestValue:
            guard let price = venue.price else { return "—" }
            return price.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        case .mostUnique:
            return "\(min(5, max(1, Int(venue.uniqueness.rounded()) + 1)))/5"
        }
    }

    func metricCaption(for venue: MartiniVenue) -> String {
        switch self {
        case .bestOverall: return "RATING"
        case .dirtiest: return "DIRTINESS"
        case .bestValue: return "\(String(format: "%.1f", venue.score)) RATING"
        case .mostUnique: return "UNIQUE"
        }
    }
}

struct RankingsView: View {
    @EnvironmentObject private var app: TinisStore
    @State private var selectedCategory: RankingCategory = .bestOverall

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.deepForest.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Rankings")
                            .font(.system(size: 31, design: .serif))
                            .foregroundStyle(TinisColor.cream)
                        Text("The fun stuff.").font(.system(size: 19, design: .serif)).foregroundStyle(TinisColor.cream.opacity(0.85))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(RankingCategory.allCases) { category in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 11) {
                                        Image(systemName: category.symbol).font(.title2).foregroundStyle(TinisColor.gold)
                                        Text(category.rawValue).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(TinisColor.cream)
                                        Text(selectedCategory == category ? "Viewing ranking" : "View ranking  →")
                                            .font(.system(size: 10, design: .rounded))
                                            .foregroundStyle(TinisColor.gold)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                                    .padding(14)
                                    .background(
                                        LinearGradient(colors: [TinisColor.forest.opacity(0.9), TinisColor.forest.opacity(0.54)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: RoundedRectangle(cornerRadius: 13)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13)
                                            .stroke(selectedCategory == category ? TinisColor.gold : TinisColor.cream.opacity(0.16), lineWidth: selectedCategory == category ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(selectedCategory.heading).font(.caption.bold()).tracking(1.2).foregroundStyle(TinisColor.gold)
                        VStack(spacing: 1) {
                            let rankedVenues = selectedCategory.sorted(app.venues)
                            ForEach(rankedVenues.indices, id: \.self) { index in
                                let venue = rankedVenues[index]
                                Button {
                                    app.selectedVenue = venue
                                } label: {
                                    HStack {
                                        Text("\(index + 1)").foregroundStyle(TinisColor.gold).frame(width: 24)
                                        VStack(alignment: .leading) {
                                            Text(venue.name)
                                            Text("\(venue.location) · \(venue.date)").font(.caption).foregroundStyle(TinisColor.cream.opacity(0.62))
                                            if !venue.note.isEmpty {
                                                Text(venue.note)
                                                    .font(.system(size: 10, design: .serif))
                                                    .foregroundStyle(TinisColor.cream.opacity(0.72))
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(selectedCategory.primaryMetric(for: venue)).font(.title3.monospacedDigit())
                                            Text(selectedCategory.metricCaption(for: venue))
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .tracking(0.6)
                                                .foregroundStyle(TinisColor.gold)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(TinisColor.cream.opacity(0.42))
                                    }
                                    .foregroundStyle(TinisColor.cream)
                                    .padding(15)
                                    .background(TinisColor.forest.opacity(0.62))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open \(venue.name) rating")
                            }
                        }.clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .sheet(item: $app.selectedVenue) {
                VenueDetailView(venue: $0)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend
    @State private var topFilter: ProfileTopFilter = .topRated
    @State private var isShowingSettings = false
    @State private var isEditingProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.deepForest.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        HStack {
                            Button {
                                isShowingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Settings")
                            Spacer()
                            Button {
                                isEditingProfile = true
                            } label: {
                                Image(systemName: "pencil")
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit profile")
                        }
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(TinisColor.cream)
                        ProfileAvatarView(
                            name: app.firstName,
                            imageData: app.profilePhotoData,
                            imageURL: backend.currentProfilePhotoURL,
                            size: 88
                        )
                            .shadow(color: .black.opacity(0.24), radius: 15, y: 6)
                        VStack(spacing: 3) {
                            Text(app.firstName).font(.system(size: 27, design: .serif))
                            Text("Martini Palate").foregroundStyle(TinisColor.cream.opacity(0.75))
                        }.foregroundStyle(TinisColor.cream)
                        TasteTags(title: "YOU TEND TO LOVE", tags: ["Gin", "Very Cold", "Lightly Dirty", "Classic", "Up", "Olives", "Silky"])
                        TasteTags(title: "YOU TEND TO DISLIKE", tags: ["Warm", "Watery", "Too Wet", "Overly Sweet"], dislike: true)
                        HStack(spacing: 12) {
                            StatCard(value: "\(String(format: "%.1f", app.venues.map(\.score).reduce(0, +) / Double(app.venues.count)))", label: "Average Rating")
                            StatCard(value: app.topVenue.name, label: "Your #1 Bar")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("YOUR TOP MARTINIS")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(TinisColor.gold)
                                Spacer()
                                Text("Choose a lens")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(TinisColor.cream.opacity(0.56))
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 7) {
                                    ForEach(ProfileTopFilter.allCases) { filter in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                topFilter = filter
                                            }
                                        } label: {
                                            Text(filter.rawValue)
                                                .font(.system(size: 10, weight: topFilter == filter ? .semibold : .medium, design: .rounded))
                                                .foregroundStyle(topFilter == filter ? TinisColor.ink : TinisColor.cream.opacity(0.76))
                                                .padding(.horizontal, 11)
                                                .padding(.vertical, 8)
                                                .background(topFilter == filter ? TinisColor.cream : TinisColor.forest, in: Capsule())
                                                .overlay(Capsule().stroke(topFilter == filter ? TinisColor.gold.opacity(0.45) : TinisColor.cream.opacity(0.14)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            VStack(spacing: 0) {
                                let topVenues = Array(topFilter.sorted(app.venues).prefix(3))
                                ForEach(topVenues.indices, id: \.self) { index in
                                    Button {
                                        app.selectedVenue = topVenues[index]
                                    } label: {
                                        ProfileTopVenueRow(rank: index + 1, venue: topVenues[index], filter: topFilter)
                                    }
                                    .buttonStyle(.plain)
                                    if index < topVenues.count - 1 {
                                        Rectangle()
                                            .fill(TinisColor.line.opacity(0.72))
                                            .frame(height: 0.5)
                                            .padding(.leading, 45)
                                    }
                                }
                            }
                            .background(TinisColor.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.gold.opacity(0.28)))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .sheet(item: $app.selectedVenue) {
                VenueDetailView(venue: $0)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingSettings) {
                ProfileSettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(TinisColor.deepForest)
            }
            .sheet(isPresented: $isEditingProfile) {
                EditProfileView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(TinisColor.paper)
            }
        }
    }
}

struct ProfilePhotoPicker: View {
    @Binding var pendingPhotoData: Data?
    let name: String
    let existingPhotoData: Data?
    let existingPhotoURL: URL?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingPhotoSource = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailable = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var displayedPhotoData: Data? {
        pendingPhotoData ?? existingPhotoData
    }

    private var hasPhoto: Bool {
        displayedPhotoData != nil || existingPhotoURL != nil
    }

    var body: some View {
        VStack(spacing: 9) {
            Button {
                isShowingPhotoSource = true
            } label: {
                ProfileAvatarView(
                    name: name,
                    imageData: displayedPhotoData,
                    imageURL: existingPhotoURL,
                    size: 96
                )
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(TinisColor.forest)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TinisColor.cream)
                    }
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(TinisColor.paper, lineWidth: 3))
                }
                .overlay {
                    if isLoading {
                        Circle()
                            .fill(Color.black.opacity(0.42))
                            .overlay(ProgressView().tint(.white))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasPhoto ? "Change profile photo" : "Add profile photo")

            Text(hasPhoto ? "Change profile photo" : "Add profile photo")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(TinisColor.forest)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color(hex: 0xA54F45))
            }
        }
        .confirmationDialog(
            hasPhoto ? "Change profile photo" : "Add profile photo",
            isPresented: $isShowingPhotoSource,
            titleVisibility: .visible
        ) {
            Button("Take Photo") {
                #if targetEnvironment(simulator)
                isShowingCameraUnavailable = true
                #else
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    isShowingCamera = true
                } else {
                    isShowingCameraUnavailable = true
                }
                #endif
            }
            Button("Choose from Library") {
                presentProfilePhotoLibraryAfterDismissal()
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $isShowingPhotoLibrary, selection: $selectedItem, matching: .images)
        .fullScreenCover(isPresented: $isShowingCamera) {
            MartiniCameraPicker(isPresented: $isShowingCamera) { capturedImage in
                preparePhoto(capturedImage)
            }
            .ignoresSafeArea()
        }
        .alert("Camera isn’t available here", isPresented: $isShowingCameraUnavailable) {
            Button("Choose from Library") {
                presentProfilePhotoLibraryAfterDismissal()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("The iOS Simulator doesn’t have a camera. Try this on your iPhone, or choose an existing photo here.")
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    guard
                        let originalData = try await newItem.loadTransferable(type: Data.self),
                        let originalImage = UIImage(data: originalData),
                        let preparedData = originalImage.tinisUploadData(maxDimension: 1000, quality: 0.84)
                    else {
                        throw MartiniPhotoError.couldNotRead
                    }
                    pendingPhotoData = preparedData
                } catch {
                    selectedItem = nil
                    errorMessage = "That photo could not be opened."
                }
                isLoading = false
            }
        }
    }

    private func preparePhoto(_ originalImage: UIImage) {
        isLoading = true
        errorMessage = nil
        if let preparedData = originalImage.tinisUploadData(maxDimension: 1000, quality: 0.84) {
            pendingPhotoData = preparedData
        } else {
            errorMessage = "That photo could not be prepared."
        }
        isLoading = false
    }

    private func presentProfilePhotoLibraryAfterDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isShowingPhotoLibrary = true
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var pendingPhotoData: Data?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var didLoad = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && (1...40).contains(trimmedName.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        ProfilePhotoPicker(
                            pendingPhotoData: $pendingPhotoData,
                            name: trimmedName.isEmpty ? app.firstName : trimmedName,
                            existingPhotoData: app.profilePhotoData,
                            existingPhotoURL: backend.currentProfilePhotoURL
                        )
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 7)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("DISPLAY NAME")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(TinisColor.moss)
                            TextField("Your name", text: $displayName)
                                .font(.system(size: 17, design: .rounded))
                                .foregroundStyle(TinisColor.ink)
                                .tint(TinisColor.forest)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(TinisColor.softWhite, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(TinisColor.line))
                                .onChange(of: displayName) { _, newValue in
                                    if newValue.count > 40 {
                                        displayName = String(newValue.prefix(40))
                                    }
                                }
                            HStack {
                                Text("This is how your friends see you.")
                                Spacer()
                                Text("\(displayName.count)/40")
                            }
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(TinisColor.ink.opacity(0.5))
                        }

                        if let saveError {
                            Text(saveError)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color(hex: 0xA54F45))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            isSaving = true
                            saveError = nil
                            Task {
                                let didSaveName = await backend.updateDisplayName(trimmedName)
                                let didSavePhoto: Bool
                                if didSaveName, let pendingPhotoData {
                                    didSavePhoto = await backend.updateProfilePhoto(pendingPhotoData)
                                } else {
                                    didSavePhoto = didSaveName
                                }

                                if didSaveName && didSavePhoto {
                                    app.firstName = trimmedName
                                    if let pendingPhotoData {
                                        app.profilePhotoData = pendingPhotoData
                                    }
                                    dismiss()
                                } else {
                                    saveError = backend.errorMessage ?? "Your profile could not be updated."
                                    isSaving = false
                                }
                            }
                        } label: {
                            HStack(spacing: 9) {
                                if isSaving { ProgressView().tint(TinisColor.cream) }
                                Text(isSaving ? "Saving…" : "Save profile")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(TinisColor.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(canSave ? TinisColor.forest : TinisColor.forest.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(22)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TinisColor.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TinisColor.forest)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                displayName = backend.currentDisplayName ?? app.firstName
                didLoad = true
            }
        }
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var backend: TinisBackend
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingSignOut = false

    private var memberCount: Int {
        backend.clubFriends.count + 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.deepForest.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        SettingsPanel(title: "YOUR CLUB") {
                            SettingsValueRow(
                                icon: "lock.fill",
                                title: "tini’s martini club",
                                detail: "Private · \(memberCount) member\(memberCount == 1 ? "" : "s")"
                            )
                            Divider()
                            HStack(spacing: 13) {
                                Image(systemName: "ticket.fill")
                                    .foregroundStyle(TinisColor.moss)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Invite code")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    Text("Share it privately with friends")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(TinisColor.ink.opacity(0.62))
                                }
                                Spacer()
                            }
                            Divider()
                            ShareLink(item: "Join my private tini’s martini club. Ask me for the club code.") {
                                SettingsActionLabel(icon: "square.and.arrow.up", title: "Share club invite")
                            }
                            .buttonStyle(.plain)
                        }

                        SettingsPanel(title: "ABOUT") {
                            SettingsValueRow(icon: "wineglass", title: "tini’s", detail: "Version 1.0")
                            Divider()
                            SettingsValueRow(icon: "hand.raised.fill", title: "Privacy", detail: "Only club members can see ratings")
                        }

                        Button(role: .destructive) {
                            isConfirmingSignOut = true
                        } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: 0xA54F45))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xA54F45).opacity(0.28)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TinisColor.deepForest, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Sign out of tini’s?", isPresented: $isConfirmingSignOut) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) {
                    Task {
                        await backend.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Your ratings stay safe. Sign in with the same Apple Account to return to the club.")
            }
        }
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(TinisColor.gold)
            VStack(spacing: 12) { content }
                .foregroundStyle(TinisColor.ink)
                .padding(15)
                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(TinisColor.line.opacity(0.9)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsValueRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(TinisColor.moss)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail).font(.system(size: 11, design: .rounded)).foregroundStyle(TinisColor.ink.opacity(0.54))
            }
            Spacer()
        }
    }
}

struct SettingsActionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(TinisColor.moss)
                .frame(width: 24)
            Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TinisColor.ink.opacity(0.34))
        }
        .foregroundStyle(TinisColor.ink)
        .contentShape(Rectangle())
    }
}

struct ProfileTopVenueRow: View {
    let rank: Int
    let venue: MartiniVenue
    let filter: ProfileTopFilter

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .medium, design: .serif).monospacedDigit())
                .foregroundStyle(TinisColor.moss)
                .frame(width: 18)
            VenueThumbnail(index: rank)
                .frame(width: 50, height: 57)
            VStack(alignment: .leading, spacing: 4) {
                Text(venue.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(venue.trait.capitalized)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(TinisColor.moss)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(filter.metricValue(for: venue))
                    .font(.system(size: 21, design: .serif).monospacedDigit())
                Text(filter.metricCaption)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(TinisColor.moss)
            }
        }
        .foregroundStyle(TinisColor.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(TinisColor.cream)
        .contentShape(Rectangle())
    }
}

struct TasteTags: View {
    let title: String
    let tags: [String]
    var dislike = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.caption.bold()).tracking(1.2).foregroundStyle(TinisColor.gold)
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(TinisColor.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(dislike ? TinisColor.blush : TinisColor.cream, in: Capsule())
                        .overlay(Capsule().stroke(dislike ? TinisColor.blush.opacity(0.6) : TinisColor.gold.opacity(0.32)))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(TinisColor.ink.opacity(0.48))
            Text(value).font(.system(size: 22, design: .serif)).multilineTextAlignment(.center).lineLimit(2)
        }
        .foregroundStyle(TinisColor.ink).frame(maxWidth: .infinity, minHeight: 94).padding(10)
        .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TinisColor.gold.opacity(0.28)))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            x += size.width + spacing; lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += lineHeight + spacing; lineHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; lineHeight = max(lineHeight, size.height)
        }
    }
}
