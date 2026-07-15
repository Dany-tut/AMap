import SwiftUI
import AMapsDomain

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941)
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)

/// Explorer profile — headline stats aggregated from the ride history plus a
/// per-activity distance breakdown. All values are derived in `AppModel`.
struct ProfileSheet: View {
    @ObservedObject var model: AppModel

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                LazyVGrid(columns: cols, spacing: 12) {
                    tile("🗺️", "\(model.coveragePercent)%", "Дананг открыт")
                    tile("🧩", "\(model.totalCellsOpened)", "ячеек")
                    tile("🚵", km(model.totalKilometers), "км всего")
                    tile("📆", "\(model.sessionCount)", "поездок")
                    tile("🔥", "\(model.streakDays)", "дней подряд")
                    tile("🏆", "\(model.unlockedTrophyCount)", "трофеев")
                }

                breakdown
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("🧭")
                .font(.system(size: 44))
                .frame(width: 88, height: 88)
                .background(Circle().fill(accent.opacity(0.16)))
            Text("Исследователь")
                .font(.title2.bold()).foregroundStyle(ink)
            Text(model.regionName)
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var breakdown: some View {
        let rows: [(ActivityType, Double)] = ActivityType.allCases
            .filter { $0 != .unknown }
            .map { ($0, model.kilometers(for: $0)) }
        let maxKm = max(rows.map(\.1).max() ?? 0, 0.1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("По видам")
                .font(.subheadline.bold()).foregroundStyle(ink)
            ForEach(rows, id: \.0) { activity, km in
                HStack(spacing: 10) {
                    Text(activity.emoji).font(.system(size: 20)).frame(width: 26)
                    Text(activity.label).font(.subheadline).foregroundStyle(ink)
                        .frame(width: 64, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(accent.opacity(km > 0 ? 0.85 : 0.15))
                            .frame(width: max(8, geo.size.width * km / maxKm))
                    }
                    .frame(height: 8)
                    Text("\(self.km(km)) км")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private func tile(_ icon: String, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 6) {
            Text(icon).font(.system(size: 26))
            Text(value).font(.title3.bold()).foregroundStyle(ink)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }

    private func km(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(1)))
    }
}
