import SwiftUI
import AMapsDomain

/// One OSM Nominatim geocoder hit.
struct GeocodeResult: Identifiable, Decodable {
    let displayName: String
    let lat: String
    let lon: String

    var id: String { "\(lat),\(lon)" }
    var coordinate: Coordinate {
        Coordinate(latitude: Double(lat) ?? 0, longitude: Double(lon) ?? 0)
    }
    /// "Дракон, мост" → title "Дракон", subtitle "мост, Дананг, …"
    var title: String { displayName.split(separator: ",").first.map(String.init) ?? displayName }
    var subtitle: String {
        displayName.split(separator: ",").dropFirst()
            .joined(separator: ",").trimmingCharacters(in: .whitespaces)
    }

    enum CodingKeys: String, CodingKey { case displayName = "display_name", lat, lon }
}

/// Place search — mirrors the web prototype's Nominatim geocoder. Type a
/// place/address, pick a result, and the map flies there.
struct SearchSheet: View {
    let map: MapController
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [GeocodeResult] = []
    @State private var loading = false
    @State private var message: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Найти место или адрес…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { Task { await search() } }
                if !query.isEmpty {
                    Button { query = ""; results = []; message = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(Capsule().fill(Color(.systemGray6)))
            .padding(.horizontal, 16).padding(.top, 22)

            if loading {
                ProgressView().padding(.top, 8)
            } else if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            }

            List(results) { r in
                Button {
                    map.recenter(on: r.coordinate, zoom: 15)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).foregroundStyle(.primary)
                        if !r.subtitle.isEmpty {
                            Text(r.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .listStyle(.plain)

            Spacer(minLength: 0)
        }
        .onAppear { focused = true }
    }

    @MainActor
    private func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        loading = true; message = nil; results = []
        defer { loading = false }

        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [
            .init(name: "format", value: "json"),
            .init(name: "limit", value: "6"),
            .init(name: "q", value: q),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("AMaps/0.1 (demo build)", forHTTPHeaderField: "User-Agent")
        req.setValue("ru", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let hits = try JSONDecoder().decode([GeocodeResult].self, from: data)
            results = hits
            if hits.isEmpty { message = "Ничего не найдено" }
        } catch {
            message = "Поиск недоступен (нет сети)"
        }
    }
}
