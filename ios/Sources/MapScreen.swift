import SwiftUI
import AMapsDomain

extension ActivityType {
    var emoji: String {
        switch self {
        case .walking: "🚶"
        case .cycling: "🚲"
        case .automotive: "🚗"
        case .unknown: "🧭"
        }
    }
    var label: String {
        switch self {
        case .walking: "Пешком"
        case .cycling: "Вело"
        case .automotive: "Авто"
        case .unknown: "—"
        }
    }
}

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941) // #7c6cf0
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)     // #3a3550

enum DockSheet: String, Identifiable {
    case search = "Поиск", journal = "Дневник", trophies = "Трофеи", profile = "Профиль"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .search: "magnifyingglass"
        case .journal: "book"
        case .trophies: "trophy"
        case .profile: "safari"
        }
    }
}

struct MapScreen: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var map = MapController()
    @State private var sheet: DockSheet?

    var body: some View {
        ZStack {
            MapLibreView(center: model.center,
                         fogOuter: model.fogOuter,
                         fogHoles: model.fogHoles,
                         controller: map)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    regionPill
                    activityPill
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()
                    rightStack
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

                dock
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .sheet(item: $sheet) { s in
            Group {
                switch s {
                case .search: SearchSheet(map: map)
                default: DockSheetView(sheet: s)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Top pills

    private var regionPill: some View {
        HStack(spacing: 5) {
            Text("🗺️")
            Text(model.regionName).fontWeight(.semibold).foregroundStyle(ink)
            Text("·").foregroundStyle(.secondary)
            Text("\(model.coveragePercent)%").fontWeight(.bold).foregroundStyle(accent)
            Text("открыто").foregroundStyle(ink)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .pillStyle()
    }

    /// Auto-detected activity (CoreMotion). Tap to override / demo.
    private var activityPill: some View {
        Button { model.cycleActivity() } label: {
            HStack(spacing: 5) {
                Text(model.activity.emoji)
                Text(model.activity.label).foregroundStyle(ink)
            }
            .lineLimit(1)
            .fixedSize()
            .pillStyle()
        }
    }

    // MARK: Right control stack (locate + zoom)

    private var rightStack: some View {
        VStack(spacing: 10) {
            roundButton(system: "location.fill", tint: accent) {
                map.recenter(on: model.center)
            }
            roundButton(system: "plus", tint: ink) { map.zoomIn() }
            roundButton(system: "minus", tint: ink) { map.zoomOut() }
        }
    }

    // MARK: Bottom dock (nav bar)

    private var dock: some View {
        HStack(spacing: 4) {
            dockIcon(.search)
            dockIcon(.journal)
            Spacer(minLength: 4)
            rideButton
            Spacer(minLength: 4)
            dockIcon(.trophies)
            dockIcon(.profile)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
        )
    }

    private func dockIcon(_ target: DockSheet) -> some View {
        Button {
            sheet = target
        } label: {
            Image(systemName: target.icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private var rideButton: some View {
        Button(action: model.toggleRide) {
            Label(model.riding ? "Стоп" : "Поехали",
                  systemImage: model.riding ? "stop.fill" : "play.fill")
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(model.riding ? Color.red.opacity(0.85) : accent))
                .shadow(color: accent.opacity(0.4), radius: 12, y: 5)
        }
    }

    // MARK: Reusable round glass button

    private func roundButton(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
    }
}

/// Placeholder content for each dock destination until the real screens land.
struct DockSheetView: View {
    let sheet: DockSheet

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: sheet.icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.top, 40)
            Text(sheet.rawValue)
                .font(.title2.bold())
                .foregroundStyle(ink)
            Text("Скоро")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    func pillStyle() -> some View {
        self
            .font(.system(size: 13.5, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.9)))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
