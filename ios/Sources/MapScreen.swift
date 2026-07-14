import SwiftUI

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941) // #7c6cf0
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)     // #3a3550

struct MapScreen: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var map = MapController()

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
                    cellsPill
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
    }

    // MARK: Top pills

    private var regionPill: some View {
        HStack(spacing: 5) {
            Text("🗺️ \(model.regionName) · ").foregroundStyle(ink)
            Text("\(model.coveragePercent)% открыто").foregroundStyle(accent)
        }
        .pillStyle()
    }

    private var cellsPill: some View {
        HStack(spacing: 5) {
            Text("🔥")
            Text("\(model.cellCount)").foregroundStyle(accent)
            Text("ячеек").foregroundStyle(ink)
        }
        .pillStyle()
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
        HStack(spacing: 6) {
            dockIcon("magnifyingglass")
            dockIcon("book")
            Spacer(minLength: 6)
            rideButton
            Spacer(minLength: 6)
            dockIcon("trophy")
            dockIcon("safari")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.72))
                .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
        )
    }

    private func dockIcon(_ system: String) -> some View {
        Button {
            // Journal / trophies / profile / search sheets land in a later milestone.
        } label: {
            Image(systemName: system)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(ink)
                .frame(width: 44, height: 44)
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
