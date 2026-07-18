import SwiftUI
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

    static var customization: AutocompleteUICustomization {
        var theme = PlacesMaterialTheme()
        theme.color.primary = TinisColor.forest
        theme.color.primaryContainer = TinisColor.forest
        theme.color.onPrimaryContainer = TinisColor.cream
        theme.color.surface = TinisColor.cream
        theme.color.onSurface = TinisColor.ink
        theme.color.onSurfaceVariant = TinisColor.ink.opacity(0.62)
        theme.color.outlineDecorative = TinisColor.gold.opacity(0.55)
        theme.shape.cornerRadius = 18
        theme.shape.cornerRadiusCard = 18
        theme.shape.cornerRadiusButton = 12
        theme.attribution.lightModeColor = .black
        theme.attribution.darkModeColor = .white
        return AutocompleteUICustomization(
            listDensity: .twoLine,
            listItemIcon: .defaultIcon,
            theme: theme
        )
    }

    static func selection(from place: Place) -> GooglePlaceSelection {
        let address = place.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GooglePlaceSelection(
            placeID: place.placeID,
            name: place.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Selected venue",
            location: compactLocation(from: place.addressComponents, fallback: address),
            fullAddress: address
        )
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
            basicPlaceAutocomplete(
                filter: TinisGooglePlaces.venueFilter,
                uiCustomization: TinisGooglePlaces.customization,
                initialQuery: initialQuery,
                show: show,
                onSelection: { place in
                    onSelection(TinisGooglePlaces.selection(from: place))
                },
                onError: { error in
                    onError(error.localizedDescription)
                }
            )
        } else {
            self
        }
    }
}
