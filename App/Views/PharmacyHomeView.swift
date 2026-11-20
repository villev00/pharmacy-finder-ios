import SwiftUI
import MapKit

struct PharmacyHomeView: View {
    @ObservedObject var model: PharmacyViewModel
    @Environment(\.openURL) private var openURL
    @State private var showAbout = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introduction
                    searchControls
                    if model.isBusy {
                        ProgressView(model.activityLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("search-progress")
                    }
                    if let message = model.message { messageCard(message) }
                    if !model.places.isEmpty { placeChoices }
                    if let origin = model.origin {
                        mapSection(origin)
                        if model.hasSearched { resultsSection }
                    } else if model.places.isEmpty && !model.isBusy {
                        welcomeCard
                    }
                    footer
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Apteekki lähellä")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tietoa sovelluksesta", systemImage: "info.circle") { showAbout = true }
                        .labelStyle(.iconOnly)
                }
            }
            .sheet(isPresented: $showAbout) { AboutView() }
        }
        .tint(Color("AccentColor"))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("LÄHELLÄ, KUN TARVITSET", systemImage: "cross.case.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color("AccentColor"))
                .accessibilityHidden(true)
            Text("Löydä lähin\napteekki.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Aloita omasta sijainnistasi tai hae osoitteella. Näet lähimmät löydetyt apteekit kartalla ja listassa.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                searchFocused = false
                Task { await model.useCurrentLocation() }
            } label: {
                Label("Käytä omaa sijaintia", systemImage: "location.fill")
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isBusy)
            .accessibilityIdentifier("use-location")
            .accessibilityHint("Pyytää sijaintiluvan ja etsii apteekit läheltäsi.")

            Text("Tai etsi ilman sijaintilupaa")
                .font(.subheadline.weight(.semibold))
            TextField("Katuosoite tai kaupunki", text: $model.query)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Katuosoite tai kaupunki")
                .accessibilityIdentifier("address-input")
                .onSubmit { submitAddress() }
            Button(action: submitAddress) {
                Label("Etsi osoite", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)
            .accessibilityIdentifier("search-address")
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func submitAddress() {
        guard !model.isBusy else { return }
        searchFocused = false
        Task { await model.searchPlaces() }
    }

    private func messageCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("status-message")
            if model.showSettings {
                Button("Avaa Asetukset") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.bordered)
            } else if model.origin != nil {
                Button("Yritä apteekkihakua uudelleen") { Task { await model.refresh() } }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var placeChoices: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Valitse hakupaikka")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(model.places) { place in
                Button {
                    Task { await model.select(place) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(place.title).font(.headline)
                            if !place.subtitle.isEmpty { Text(place.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(model.isBusy)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("place-\(place.id)")
                .accessibilityHint("Etsii apteekkeja tämän paikan läheltä.")
            }
        }
    }

    private func mapSection(_ origin: SearchOrigin) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(origin.title, systemImage: origin.isDeviceLocation ? "location.fill" : "mappin.and.ellipse")
                    .font(.headline)
                Spacer(minLength: 8)
                Button("Päivitä", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    .labelStyle(.iconOnly)
                    .disabled(model.isBusy)
                    .accessibilityLabel("Päivitä apteekkihaku")
            }
            PharmacyMapView(origin: origin, results: model.results)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            if let accuracy = origin.accuracy, accuracy > 1_000 {
                Label("Sijainti on likimääräinen. Tarkenna hakua halutessasi osoitteella.", systemImage: "location.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.results.isEmpty {
                ContentUnavailableView("Apteekkeja ei löytynyt",
                    systemImage: "cross.case", description: Text("Apple Maps ei palauttanut apteekkeja 50 km:n säteeltä. Kokeile läheistä kaupunkia tai toista osoitetta."))
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Lähimmät löytyneet").font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(model.results.count) tulosta").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("Linnuntietä valitusta paikasta")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                    PharmacyResultCard(result: result, isNearest: index == 0)
                }
            }
        }
        .accessibilityIdentifier("pharmacy-results")
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "map.fill").font(.system(size: 36)).foregroundStyle(Color("AccentColor"))
                .accessibilityHidden(true)
            Text("Oikea paikka, helpommin.").font(.title3.bold())
            Text("Kartta, etäisyys ja kävelyreitti samassa paikassa. Osoitehaku toimii myös ilman sijaintilupaa.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color("AccentColor").opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }

    private var footer: some View {
        Text("Karttatiedot: Apple Maps. Tulokset eivät välttämättä kata kaikkia apteekkeja. Varmista aukiolo ja tarvitsemasi tuotteen saatavuus apteekista.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)
    }
}

struct PharmacyMapView: View {
    let origin: SearchOrigin
    let results: [NearbyPharmacy]
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            Annotation(origin.title, coordinate: origin.coordinate.mapCoordinate) {
                Image(systemName: "location.circle.fill")
                    .font(.title).symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue)
                    .accessibilityLabel("Hakupaikka: \(origin.title)")
            }
            ForEach(results) { result in
                Marker(result.pharmacy.name, systemImage: "cross.case.fill",
                       coordinate: result.pharmacy.coordinate.mapCoordinate)
                    .tint(Color("AccentColor"))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .onChange(of: origin.coordinate) { _, _ in resetCamera() }
        .onChange(of: results.map(\.id)) { _, _ in resetCamera() }
        .onAppear { resetCamera() }
        .accessibilityLabel("Apteekkien kartta")
        .accessibilityHint("Samat apteekit ja etäisyydet löytyvät myös kartan alla olevasta listasta.")
    }

    private func resetCamera() {
        let distance = max(2_000, (results.prefix(6).last?.distance ?? 1_000) * 2.5)
        position = .region(MKCoordinateRegion(center: origin.coordinate.mapCoordinate,
                                             latitudinalMeters: distance, longitudinalMeters: distance))
    }
}

struct PharmacyResultCard: View {
    let result: NearbyPharmacy
    let isNearest: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isNearest {
                Label("Lähin löydetty", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color("AccentColor"))
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(result.pharmacy.name).font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(result.pharmacy.address.isEmpty ? "Osoite ei saatavilla" : result.pharmacy.address)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(result.distanceLabel)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color("AccentColor").opacity(0.1), in: Capsule())
                    .accessibilityLabel("Etäisyys linnuntietä \(result.distanceLabel)")
            }
            if let mapsURL = result.pharmacy.mapsURL {
                Link(destination: mapsURL) {
                    Label("Kävelyreitti", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Kävelyreitti: \(result.pharmacy.name)")
                .accessibilityHint("Avaa reittiohjeet Apple Mapsissa.")
            }
            if result.pharmacy.phone != nil || result.pharmacy.website != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { contactLinks }
                    VStack(alignment: .leading, spacing: 12) { contactLinks }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isNearest ? Color("AccentColor").opacity(0.35) : .clear, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pharmacy-\(result.id)")
    }

    @ViewBuilder private var contactLinks: some View {
        if let phone = result.pharmacy.phone {
            let digits = phone.filter { $0.isNumber || $0 == "+" }
            if let url = URL(string: "tel:\(digits)"), !digits.isEmpty {
                Link(destination: url) { Label("Soita", systemImage: "phone") }
                    .accessibilityLabel("Soita apteekkiin \(result.pharmacy.name)")
            }
        }
        if let website = result.pharmacy.website,
           ["https", "http"].contains(website.scheme?.lowercased() ?? "") {
            Link(destination: website) { Label("Verkkosivut", systemImage: "arrow.up.right.square") }
                .accessibilityLabel("Apteekin \(result.pharmacy.name) verkkosivut")
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Sijainti on valintasi") {
                    Text("Sovellus pyytää sijaintilupaa vain, kun valitset oman sijainnin. Sijaintia ei seurata taustalla. Osoitehaku toimii ilman sijaintilupaa.")
                }
                Section("Tietojen käsittely") {
                    Text("Valitsemasi hakupaikka ja hakuteksti välitetään Apple Mapsille tulosten hakemista varten. Sovelluksella ei ole omaa palvelinta, analytiikkaa tai käyttäjätiliä. Hakuhistoriaa tai sijaintia ei tallenneta sovelluksen pysyvään muistiin.")
                    Link("Apple Mapsin tietosuoja", destination: URL(string: "https://www.apple.com/legal/privacy/data/en/apple-maps/")!)
                }
                Section("Tulosten tulkinta") {
                    Text("Apteekit järjestetään linnuntie-etäisyyden mukaan. Apple Mapsin hakutulokset voivat olla puutteellisia. Lähin löydetty ei takaa, että se on lähin olemassa oleva apteekki.")
                    Text("Kävelyreitti avautuu Apple Mapsiin. Sen pituus voi poiketa listan etäisyydestä. Aukioloaikoja tai varastotietoja ei vahvisteta tässä sovelluksessa.")
                }
            }
            .navigationTitle("Tietoa")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Valmis") { dismiss() } } }
        }
    }
}
