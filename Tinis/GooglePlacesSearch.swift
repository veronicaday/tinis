import SwiftUI
import UIKit
import GooglePlacesSwift

struct GooglePlaceSelection: Equatable {
    let placeID: String?
    let name: String
    let location: String
    let fullAddress: String?
}

@MainActor
enum TinisGooglePlaces {
    private static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty && !apiKey.contains("$(") && !apiKey.contains("YOUR_")
    }

    @discardableResult
    static func configure() -> Bool {
        guard isConfigured else { return false }
        return PlacesClient.provideAPIKey(apiKey)
    }

    static let venueFilter = AutocompleteFilter(types: [.bar, .restaurant, .nightClub, .lodging])

    static func selection(from place: Place) -> GooglePlaceSelection {
        let address = place.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GooglePlaceSelection(
            placeID: place.placeID,
            name: place.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Selected venue",
            location: compactLocation(from: place.addressComponents, fallback: address),
            fullAddress: address
        )
    }

    static func selection(
        for suggestion: AutocompletePlaceSuggestion,
        sessionToken: AutocompleteSessionToken
    ) async -> Result<GooglePlaceSelection, PlacesError> {
        let request = FetchPlaceRequest(
            placeID: suggestion.placeID,
            placeProperties: [.placeID, .displayName, .formattedAddress, .addressComponents],
            sessionToken: sessionToken
        )
        return await PlacesClient.shared.fetchPlace(with: request)
            .map(selection(from:))
    }

    static func log(_ error: PlacesError) {
#if DEBUG
        let diagnostic = error as NSError
        print(
            "Google Places error [\(diagnostic.domain) \(diagnostic.code)]: " +
            "\(String(reflecting: error)); \(diagnostic.localizedDescription)"
        )
#endif
    }

    static var googleAttributionImage: UIImage? {
        let outerURL = Bundle.main.url(
            forResource: "GooglePlaces_GooglePlacesTarget",
            withExtension: "bundle"
        ) ?? Bundle.main.bundleURL.appendingPathComponent("GooglePlaces_GooglePlacesTarget.bundle")

        guard let outerBundle = Bundle(url: outerURL) else { return nil }
        let innerURL = outerBundle.url(forResource: "GooglePlaces", withExtension: "bundle")
            ?? outerBundle.bundleURL.appendingPathComponent("GooglePlaces.bundle")
        guard let googleBundle = Bundle(url: innerURL) else { return nil }

        if let image = UIImage(
            named: "build-with-google-black",
            in: googleBundle,
            compatibleWith: nil
        ) {
            return image
        }

        for scale in ["@3x", "@2x"] {
            if let path = googleBundle.path(
                forResource: "build-with-google-black\(scale)",
                ofType: "png"
            ), let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    private static func compactLocation(
        from components: [AddressComponent]?,
        fallback address: String?
    ) -> String {
        let cityComponent = components?.first {
            $0.types.contains(.locality) || $0.types.contains(.postalTown)
        }
        let regionComponent = components?.first { $0.types.contains(.administrativeAreaLevel1) }
        let city = cityComponent?.name
        let region = regionComponent?.shortName ?? regionComponent?.name

        if let city, let region { return "\(city), \(region)" }
        if let city { return city }

        guard let address else { return "Location unavailable" }
        let parts = address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 3 else { return address }

        let cityIndex = max(0, parts.count - 3)
        let regionText = parts[parts.count - 2]
            .split(separator: " ")
            .prefix { part in !part.contains(where: \Character.isNumber) }
            .joined(separator: " ")
        return regionText.isEmpty ? parts[cityIndex] : "\(parts[cityIndex]), \(regionText)"
    }
}

@MainActor
private struct TinisPlaceSearchDrawer: View {
    @Binding var isPresented: Bool
    let onSelection: (GooglePlaceSelection) -> Void
    let onError: (String) -> Void

    @State private var query: String
    @State private var suggestions: [AutocompletePlaceSuggestion] = []
    @State private var isSearching = false
    @State private var resolvingPlaceID: String?
    @State private var inlineError: String?
    @FocusState private var searchIsFocused: Bool

    private let sessionToken = AutocompleteSessionToken()

    init(
        isPresented: Binding<Bool>,
        initialQuery: String,
        onSelection: @escaping (GooglePlaceSelection) -> Void,
        onError: @escaping (String) -> Void
    ) {
        _isPresented = isPresented
        _query = State(initialValue: initialQuery)
        self.onSelection = onSelection
        self.onError = onError
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
                .padding(.top, 20)

            Rectangle()
                .fill(TinisColor.line.opacity(0.7))
                .frame(height: 1)
                .padding(.top, 18)

            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            attribution
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(TinisColor.cream)
        .task(id: query) {
            await findSuggestions(for: query)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Find a martini")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(TinisColor.forest)
                Text("Search bars and restaurants")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(TinisColor.ink.opacity(0.55))
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TinisColor.ink.opacity(0.72))
                    .frame(width: 34, height: 34)
                    .background(TinisColor.paper, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close venue search")
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TinisColor.moss)

            TextField("Try Dante or Bemelmans Bar", text: $query)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(TinisColor.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchIsFocused)

            if isSearching {
                ProgressView()
                    .controlSize(.small)
                    .tint(TinisColor.forest)
            } else if !query.isEmpty {
                Button {
                    query = ""
                    searchIsFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TinisColor.ink.opacity(0.28))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 52)
        .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(searchIsFocused ? TinisColor.forest.opacity(0.65) : TinisColor.gold.opacity(0.38), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var results: some View {
        if let inlineError {
            ContentUnavailableView {
                Label("Search took a spill", systemImage: "wineglass")
            } description: {
                Text(inlineError)
            } actions: {
                Button("Try again") {
                    let currentQuery = query
                    query = ""
                    Task { @MainActor in query = currentQuery }
                }
                .buttonStyle(.bordered)
                .tint(TinisColor.forest)
            }
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(TinisColor.gold)
                Text("Where are we drinking?")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(TinisColor.forest)
                Text("Type a bar or restaurant to find it.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(TinisColor.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if suggestions.isEmpty && !isSearching {
            ContentUnavailableView(
                "No venues found",
                systemImage: "magnifyingglass",
                description: Text("Try another name or add the city.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(suggestions, id: \.placeID) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func suggestionRow(_ suggestion: AutocompletePlaceSuggestion) -> some View {
        Button {
            choose(suggestion)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "wineglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TinisColor.gold)
                    .frame(width: 38, height: 38)
                    .background(TinisColor.forest, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.legacyAttributedPrimaryText.string)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(TinisColor.ink)
                        .lineLimit(1)
                    if let secondary = suggestion.legacyAttributedSecondaryText?.string,
                       !secondary.isEmpty {
                        Text(secondary)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(TinisColor.ink.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if resolvingPlaceID == suggestion.placeID {
                    ProgressView()
                        .controlSize(.small)
                        .tint(TinisColor.forest)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TinisColor.moss)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(resolvingPlaceID != nil)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TinisColor.line.opacity(0.65))
                .frame(height: 1)
                .padding(.leading, 51)
        }
    }

    @ViewBuilder
    private var attribution: some View {
        if let image = TinisGooglePlaces.googleAttributionImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 14)
                .padding(.top, 8)
                .accessibilityLabel("Built with Google")
        }
    }

    private func findSuggestions(for rawQuery: String) async {
        let trimmedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            suggestions = []
            inlineError = nil
            isSearching = false
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        isSearching = true
        inlineError = nil
        let request = AutocompleteRequest(
            query: trimmedQuery,
            sessionToken: sessionToken,
            filter: TinisGooglePlaces.venueFilter,
            inputOffset: trimmedQuery.count
        )
        let result = await PlacesClient.shared.fetchAutocompleteSuggestions(with: request)
        guard !Task.isCancelled else { return }
        isSearching = false

        switch result {
        case let .success(rawSuggestions):
            suggestions = rawSuggestions.compactMap { result in
                guard case let .place(suggestion) = result else { return nil }
                return suggestion
            }
        case let .failure(error):
            TinisGooglePlaces.log(error)
            suggestions = []
            inlineError = "We couldn’t reach Google Places. Check your connection and try again."
        }
    }

    private func choose(_ suggestion: AutocompletePlaceSuggestion) {
        resolvingPlaceID = suggestion.placeID
        inlineError = nil

        Task { @MainActor in
            switch await TinisGooglePlaces.selection(for: suggestion, sessionToken: sessionToken) {
            case let .success(selection):
                onSelection(selection)
                isPresented = false
            case let .failure(error):
                TinisGooglePlaces.log(error)
                resolvingPlaceID = nil
                inlineError = "We found the venue but couldn’t load its details. Please try again."
                onError(error.localizedDescription)
            }
        }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension View {
    @MainActor
    @ViewBuilder
    func tinisPlaceSearch(
        show: Binding<Bool>,
        initialQuery: String = "",
        onSelection: @escaping (GooglePlaceSelection) -> Void,
        onError: @escaping (String) -> Void
    ) -> some View {
        if TinisGooglePlaces.isConfigured {
            sheet(isPresented: show) {
                TinisPlaceSearchDrawer(
                    isPresented: show,
                    initialQuery: initialQuery,
                    onSelection: onSelection,
                    onError: onError
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(TinisColor.cream)
            }
        } else {
            self
        }
    }
}
