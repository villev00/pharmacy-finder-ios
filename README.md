# Apteekki lähellä · iOS

[![iOS build and tests](https://github.com/villev00/pharmacy-finder-ios/actions/workflows/ios.yml/badge.svg)](https://github.com/villev00/pharmacy-finder-ios/actions/workflows/ios.yml)

A native SwiftUI app for finding nearby pharmacies. Use your device location or search for an address without granting location access. Results appear on an Apple Maps map and in a list ordered by straight-line distance. The interface is in Finnish.

## Features

- One-time, foreground location request initiated by the user.
- Address and city search with an explicit choice of the matching location.
- Pharmacy category search through MapKit, expanding from 5 km to 20 km and finally 50 km when necessary.
- Distance ordering, duplicate removal, a clear closest-result label, walking directions, and available contact links.
- Empty results, denied location permission, imprecise location, timeouts, and recoverable network errors.
- Dynamic Type, VoiceOver labels, semantic colors, light and dark appearance, and a list alternative to the map.
- No account, API key, application backend, analytics SDK, or persisted search history.

“Closest” means closest among the results returned by Apple Maps. Results may not include every pharmacy. Distances in the list are straight-line distances, not walking distances. Opening hours and stock availability are not inferred.

## Run on a Mac

Requirements: Xcode 16 or newer, an iOS 17+ simulator or device, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open NearbyPharmacy.xcodeproj
```

Choose the `NearbyPharmacy` scheme and an iPhone simulator, then run. MapKit requires an internet connection for real searches. The Xcode project is generated from the committed `project.yml`; no third-party runtime dependencies are needed.

To run on an iPhone, connect it to Xcode, select your own signing team under **Signing & Capabilities**, use an available bundle identifier, and select the phone as the run destination. The repository and CI artifacts are source/build-test deliverables; an unsigned simulator build is not an installable iPhone app.

## Tests

The [GitHub Actions workflow](https://github.com/villev00/pharmacy-finder-ios/actions/workflows/ios.yml) generates the project, selects an installed iPhone simulator, builds the app, and runs 13 unit tests and two UI tests. Build logs, the `.xcresult` bundle, and attached UI screenshots are retained as workflow artifacts.

Local test command, replacing the destination with an available simulator from `xcrun simctl list devices available`:

```sh
xcodegen generate
xcodebuild test \
  -project NearbyPharmacy.xcodeproj \
  -scheme NearbyPharmacy \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Unit tests cover distance calculations, ordering, duplicate removal, search boundaries, directions URLs, the address-only flow, denied location, empty results, network retry, and device-location search. UI tests exercise manual search and the denied-permission alternative using deterministic injected services. They do not make claims about the completeness of Apple's live data.

The app was authored in a Windows workspace, where Xcode and the iOS SDK are unavailable. Local structural checks are provided in `scripts/validate_project.py`. The Actions run is the source of truth for the actual Apple-platform build and test result; a prepared workflow alone does not mean those checks passed.

```sh
python3 scripts/validate_project.py
```

For a manual acceptance pass on a simulator or phone:

1. Search for a real city or street, select the correct match, and inspect the nearest results.
2. Allow location once; confirm that results are centered on that location.
3. Deny location; verify that address search still works.
4. Try an address with no matches and disable the network to check the retry state.
5. Open walking directions, inspect dark mode and large text, and navigate the results with VoiceOver.

## Structure

| Area | Responsibility |
|---|---|
| `App/Models` | Coordinates, distance calculation, result ranking, links |
| `App/Services` | Apple Maps requests and a bounded CoreLocation request |
| `App/ViewModels` | Search state, recovery, and protection against stale responses |
| `App/Views` | SwiftUI search, map, result cards, and privacy explanation |
| `Tests`, `UITests` | Unit coverage and deterministic interface flows |

Search and location providers are injected behind protocols. The UI tests use launch arguments to select fixtures. Normal launches use CoreLocation and MapKit. Location authorization is never requested at startup.

## Data handling

MapKit receives the search text or selected coordinates to return map data. This app does not send them to its own server or write them to persistent storage. Opening a route, calling a pharmacy, or visiting its website hands the action to the corresponding system app. See [Apple Maps privacy information](https://www.apple.com/legal/privacy/data/en/apple-maps/) for Apple's handling of its service data.

## Apple API references

- [MKLocalSearch.Request](https://developer.apple.com/documentation/mapkit/mklocalsearch/request)
- [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)
- [Core Location](https://developer.apple.com/documentation/corelocation)
