import SwiftUI

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941) // #7c6cf0

struct MapScreen: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            MapLibreView(center: model.center)
                .ignoresSafeArea()

            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    regionPill
                    cellsPill
                    Spacer(minLength: 0)
                }
                Spacer()
                rideButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var regionPill: some View {
        HStack(spacing: 5) {
            Text("🗺️ \(model.regionName) · ")
                .foregroundStyle(.primary)
            Text("\(model.coveragePercent)% открыто")
                .foregroundStyle(accent)
        }
        .pillStyle()
    }

    private var cellsPill: some View {
        HStack(spacing: 5) {
            Text("🔥")
            Text("\(model.cellCount)").foregroundStyle(accent)
            Text("ячеек").foregroundStyle(.primary)
        }
        .pillStyle()
    }

    private var rideButton: some View {
        Button(action: model.toggleRide) {
            Text(model.riding ? "Стоп" : "▶ Поехали")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 16)
                .background(Capsule().fill(model.riding ? Color.red.opacity(0.85) : accent))
                .shadow(color: accent.opacity(0.4), radius: 14, y: 6)
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
