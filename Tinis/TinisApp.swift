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
                .onOpenURL { url in
                    Task { await backend.handleOpenURL(url) }
                }
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
        case .dirtiest: return "DIRTY"
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
    @Published var hasOnboarded = false
    @Published var selectedTab = 0
    @Published var firstName = "Veronica"
    @Published var selectedVenue: MartiniVenue?
    @Published var pendingGooglePlace: GooglePlaceSelection?
    @Published var venues: [MartiniVenue] = [
        .init(name: "Bemelmans Bar", location: "New York, NY", score: 8.9, ratingCount: 7, date: "May 12, 2024", trait: "cold, lightly dirty", dirtiness: 3.2, chilliness: 4.0, uniqueness: 2.1, spiritForward: 3.7, elo: 1628),
        .init(name: "Dante", location: "New York, NY", score: 8.7, ratingCount: 6, date: "Apr 28, 2024", trait: "bright, classic", dirtiness: 0.8, chilliness: 3.4, uniqueness: 1.1, spiritForward: 2.8, elo: 1606),
        .init(name: "Employees Only", location: "New York, NY", score: 8.4, ratingCount: 5, date: "May 15, 2024", trait: "clean, spirit-forward", dirtiness: 0.3, chilliness: 2.8, uniqueness: 3.1, spiritForward: 4.0, elo: 1574),
        .init(name: "The Savoy", location: "London, UK", score: 8.3, ratingCount: 4, date: "Feb 9, 2024", trait: "silky, perfectly cold", dirtiness: 1.4, chilliness: 3.9, uniqueness: 1.7, spiritForward: 2.3, elo: 1558),
        .init(name: "Clover Club", location: "Brooklyn, NY", score: 8.1, ratingCount: 3, date: "Jan 20, 2024", trait: "soft, lemony", dirtiness: 3.8, chilliness: 2.2, uniqueness: 4.0, spiritForward: 1.2, elo: 1531)
    ]

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            hasOnboarded = true
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-search") {
            selectedTab = 1
        }
#endif
    }

    var topVenue: MartiniVenue { venues.sorted { $0.elo > $1.elo }.first! }

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
            selectedVenue = venues[index]
        } else {
            venues.append(venue)
            selectedVenue = venue
        }
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
                date: "Shared club",
                trait: "\(cold), \(dirty)",
                dirtiness: row.dirtiness ?? 2,
                chilliness: row.chilliness ?? 2,
                uniqueness: row.uniqueness ?? 2,
                spiritForward: row.spiritForward ?? 2,
                elo: 1500
            )
        }
    }
}

// MARK: - Theme

enum TinisColor {
    static let forest = Color(hex: 0x063C2E)
    static let deepForest = Color(hex: 0x00271D)
    static let darkestForest = Color(hex: 0x001A13)
    static let cream = Color(hex: 0xF8F3EC)
    static let paper = Color(hex: 0xEFE7DC)
    static let ink = Color(hex: 0x17231E)
    static let gold = Color(hex: 0xC9AE72)
    static let paleGold = Color(hex: 0xE7D7AD)
    static let blush = Color(hex: 0xDDAEA7)
    static let moss = Color(hex: 0x718155)
    static let line = Color(hex: 0xD8CCBC)
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

struct TinisRootView: View {
    @EnvironmentObject private var app: TinisStore
    @EnvironmentObject private var backend: TinisBackend

    var body: some View {
        Group {
            if backend.isConfigured && backend.phase != .ready {
                TinisAuthGateView()
            } else if app.hasOnboarded {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .onChange(of: backend.leaderboard, initial: true) { _, rows in
            app.syncFromBackend(rows)
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

    private var glow: Color {
        [Color(hex: 0xB76D32), Color(hex: 0x82955A), Color(hex: 0x9B5540), Color(hex: 0xA88C4B)][variant % 4]
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let glassWidth = side * 0.67
            let bowlHeight = side * 0.34
            let stemHeight = side * 0.31
            ZStack {
                LinearGradient(
                    colors: [Color.black, TinisColor.darkestForest, Color.black.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(glow.opacity(0.58))
                    .frame(width: side * 0.58)
                    .blur(radius: side * 0.19)
                    .offset(x: side * 0.28, y: -side * 0.25)
                Circle()
                    .fill(TinisColor.gold.opacity(0.20))
                    .frame(width: side * 0.36)
                    .blur(radius: side * 0.11)
                    .offset(x: -side * 0.34, y: side * 0.25)
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? TinisColor.paleGold.opacity(0.45) : glow.opacity(0.38))
                        .frame(width: side * CGFloat(0.035 + Double(index) * 0.01))
                        .blur(radius: side * 0.018)
                        .offset(
                            x: side * CGFloat(-0.43 + Double(index) * 0.22),
                            y: side * CGFloat(-0.37 + Double(index % 3) * 0.16)
                        )
                }

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        MartiniBowl()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.34), TinisColor.paleGold.opacity(0.26), Color.white.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        MartiniBowl()
                            .stroke(Color.white.opacity(0.76), lineWidth: max(0.8, side * 0.006))
                        Ellipse()
                            .stroke(Color.white.opacity(0.72), lineWidth: max(0.7, side * 0.005))
                            .frame(width: glassWidth, height: side * 0.045)
                            .offset(y: -side * 0.017)
                        Ellipse()
                            .fill(TinisColor.paleGold.opacity(0.28))
                            .frame(width: glassWidth * 0.88, height: side * 0.033)
                            .offset(y: side * 0.035)

                        if showOlives {
                            Capsule()
                                .fill(TinisColor.paleGold.opacity(0.85))
                                .frame(width: glassWidth * 0.63, height: max(1, side * 0.009))
                                .rotationEffect(.degrees(-18))
                                .offset(x: glassWidth * 0.05, y: bowlHeight * 0.45)
                            HStack(spacing: -side * 0.018) {
                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [Color(hex: 0xB4A455), Color(hex: 0x59612D)],
                                                center: .topLeading,
                                                startRadius: 0,
                                                endRadius: side * 0.075
                                            )
                                        )
                                        .frame(width: side * 0.105, height: side * 0.105)
                                        .overlay(Circle().fill(Color(hex: 0x6A2E25)).frame(width: side * 0.025))
                                        .offset(y: CGFloat(index) * side * 0.025)
                                }
                            }
                            .rotationEffect(.degrees(-18))
                            .offset(x: -glassWidth * 0.03, y: bowlHeight * 0.46)
                        }
                    }
                    .frame(width: glassWidth, height: bowlHeight)

                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.82), Color.white.opacity(0.18)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(1.5, side * 0.012), height: stemHeight)
                    Ellipse()
                        .fill(Color.white.opacity(0.34))
                        .overlay(Ellipse().stroke(Color.white.opacity(0.65), lineWidth: max(0.7, side * 0.004)))
                        .frame(width: glassWidth * 0.50, height: side * 0.045)
                }
                .shadow(color: TinisColor.paleGold.opacity(0.28), radius: side * 0.04)
                .offset(y: side * 0.07)
            }
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
                .offset(y: 300)
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
                Text("The dirtier,\nthe better.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TinisColor.cream)
                    .lineSpacing(4)
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

    private let demoActivity = [
        FriendActivity(friend: "Sarah", initials: "S", venueName: "Bemelmans Bar", location: "New York, NY", score: 9.2, trait: "Very cold · lightly dirty", note: "Perfectly cold and exactly dirty enough.", time: "12 min ago", rankingUpdate: "New #1", avatarHex: 0xC85B68, artworkVariant: 0, photoURL: nil),
        FriendActivity(friend: "Alex", initials: "A", venueName: "Dante", location: "New York, NY", score: 8.4, trait: "Bright · classic", note: "A crisp one. The lemon twist really works.", time: "1 hr ago", rankingUpdate: "Moved to #2", avatarHex: 0x5A9181, artworkVariant: 1, photoURL: nil),
        FriendActivity(friend: "Maya", initials: "M", venueName: "Clover Club", location: "Brooklyn, NY", score: 8.8, trait: "Silky · olive", note: "Would immediately order another.", time: "Last night", rankingUpdate: "New entry", avatarHex: 0xA475B5, artworkVariant: 2, photoURL: nil),
        FriendActivity(friend: "Jack", initials: "J", venueName: "Employees Only", location: "New York, NY", score: 7.5, trait: "Spirit-forward · clean", note: "Strong, serious, and maybe a little too warm.", time: "Yesterday", rankingUpdate: "Now #4", avatarHex: 0xB27645, artworkVariant: 3, photoURL: nil)
    ]

    private var activity: [FriendActivity] {
        guard backend.isConfigured else { return demoActivity }
        return backend.friendFeed.enumerated().map { index, row in
            let initial = String(row.displayName.prefix(1)).uppercased()
            let cold = (row.chilliness ?? 2) >= 3 ? "Very cold" : "Soft"
            let dirty = (row.dirtiness ?? 2) >= 3 ? "dirty" : "clean"
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
                photoURL: backend.photoURLs[row.id]
            )
        }
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
                                FriendActivityCard(activity: item) {
                                    app.selectedVenue = app.venues.first { $0.name == item.venueName }
                                }
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

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: activity.avatarHex))
                        .frame(width: 38, height: 38)
                        .overlay(Text(activity.initials).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white))
                        .overlay(Circle().stroke(TinisColor.gold.opacity(0.42)))
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
            .padding(14)
            .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(TinisColor.gold.opacity(0.28)))
            .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(activity.friend) rated \(activity.venueName) \(activity.score, format: .number.precision(.fractionLength(1))). \(activity.rankingUpdate)")
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
    let venue: MartiniVenue
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack(alignment: .bottomLeading) {
                        MartiniArtwork(variant: abs(venue.name.hashValue) % 4)
                            .frame(height: 285)
                        LinearGradient(colors: [.clear, Color.black.opacity(0.84)], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(venue.name)
                                .font(.system(size: 30, design: .serif))
                            Text(venue.location)
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
                            Text("YOUR LATEST RATING")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(TinisColor.moss)
                            Text(venue.date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ScoreBadge(score: venue.score)
                    }

                    InfoCard(title: "Would order again") {
                        HStack { Text("Absolutely").foregroundStyle(TinisColor.forest).fontWeight(.semibold); Spacer(); Text("$19").foregroundStyle(.secondary) }
                    }

                    TraitSummary()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("FRIEND RATINGS").font(.caption.bold()).tracking(1.2)
                        HStack(spacing: 17) {
                            FriendScore(name: "You", score: venue.score, color: TinisColor.moss)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(TinisColor.forest)
                }
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
    private let rows = [
        ("Dirtiness", "Clean", "Filthy", 3, "olive"),
        ("Chilliness", "Warm", "Arctic", 4, "snowflake"),
        ("Uniqueness", "Classic", "Wild", 2, "sparkles"),
        ("Spirit-forward", "Smooth", "Rocket fuel", 4, "martini")
    ]
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
                                photoData: $photoData,
                                searchVenue: openVenueSearch
                            )
                        }
                        if stage == 1 { TraitsStep(traits: $traits, spirit: spirit, garnish: garnish, servingStyle: servingStyle) }
                        if stage == 2 { DuelStep(comparison: app.topVenue, choice: $duelChoice) }
                        Button {
                            if stage < 2 { stage += 1 } else {
                                guard !isSaving else { return }
                                isSaving = true
                                let comparison = app.topVenue
                                let updatedElo = TinisElo.updatedRatings(
                                    pastRating: comparison.elo,
                                    choice: duelChoice
                                )
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
                                    elo: updatedElo.new
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
                                                photoData: photoData
                                            )
                                            if let photoWarning {
                                                app.updateElo(for: comparison, to: updatedElo.past)
                                                app.add(newVenue)
                                                resetForm()
                                                didSaveDespiteNotice = true
                                                saveNotice = photoWarning
                                                return
                                            }
                                        }
                                        app.updateElo(for: comparison, to: updatedElo.past)
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
            }
            .padding(15)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.line.opacity(0.9)))
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
                isShowingPhotoLibrary = true
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
                isShowingPhotoLibrary = true
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
        .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 13))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Which would you rather order again?")
                .font(.system(size: 27, design: .serif))
                .foregroundStyle(TinisColor.ink)
            Text("This keeps your personal rankings interesting without making every rating a chore.")
                .foregroundStyle(TinisColor.ink.opacity(0.62))
            HStack(spacing: 14) {
                DuelCard(title: "The new martini", subtitle: "Unranked", selected: choice == .new) { choice = .new }
                DuelCard(title: comparison.name, subtitle: "Your current #1", selected: choice == .old) { choice = .old }
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

struct RankingsView: View {
    @EnvironmentObject private var app: TinisStore
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
                            let categories = [("Best Overall", "star.fill"), ("Dirtiest", "drop.fill"), ("Coldest", "snowflake"), ("Most Unique", "sparkles")]
                            ForEach(categories.indices, id: \.self) { index in
                                let item = categories[index]
                                VStack(alignment: .leading, spacing: 11) {
                                    Image(systemName: item.1).font(.title2).foregroundStyle(TinisColor.gold)
                                    Text(item.0).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(TinisColor.cream)
                                    Text("View ranking  →").font(.system(size: 10, design: .rounded)).foregroundStyle(TinisColor.gold)
                                }
                                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                                .padding(14)
                                .background(
                                    LinearGradient(colors: [TinisColor.forest.opacity(0.9), TinisColor.forest.opacity(0.54)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 13)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(TinisColor.cream.opacity(0.16)))
                            }
                        }
                        Text("YOUR PERSONAL ORDER").font(.caption.bold()).tracking(1.2).foregroundStyle(TinisColor.gold)
                        VStack(spacing: 1) {
                            let rankedVenues = app.venues.sorted { $0.elo > $1.elo }
                            ForEach(rankedVenues.indices, id: \.self) { index in
                                let venue = rankedVenues[index]
                                HStack {
                                    Text("\(index + 1)").foregroundStyle(TinisColor.gold).frame(width: 24)
                                    VStack(alignment: .leading) { Text(venue.name); Text("Elo \(venue.elo)").font(.caption).foregroundStyle(TinisColor.cream.opacity(0.62)) }
                                    Spacer()
                                    Text(venue.score, format: .number.precision(.fractionLength(1))).font(.title3.monospacedDigit())
                                }
                                .foregroundStyle(TinisColor.cream).padding(15)
                                .background(TinisColor.forest.opacity(0.62))
                            }
                        }.clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var app: TinisStore
    @State private var topFilter: ProfileTopFilter = .topRated

    var body: some View {
        NavigationStack {
            ZStack {
                TinisColor.deepForest.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        HStack {
                            Image(systemName: "gearshape")
                            Spacer()
                            Image(systemName: "pencil")
                        }
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(TinisColor.cream)
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: 0xD75462), Color(hex: 0xD28B3B)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88)
                            .overlay(Text(String(app.firstName.prefix(1))).font(.system(size: 36, design: .serif)).foregroundStyle(.white))
                            .overlay(Circle().stroke(TinisColor.gold.opacity(0.65), lineWidth: 1.5))
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
                        InfoCard(title: "YOUR IDEAL MARTINI") {
                            HStack(alignment: .center, spacing: 14) {
                                Text("Gin martini, very cold, lightly dirty, bone dry, up, olives.")
                                    .font(.system(size: 18, design: .serif))
                                Spacer(minLength: 0)
                                Image(systemName: "wineglass")
                                    .font(.system(size: 31, weight: .ultraLight))
                                    .foregroundStyle(TinisColor.moss)
                            }
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
        }
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
