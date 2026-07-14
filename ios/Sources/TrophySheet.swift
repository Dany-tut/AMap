import SwiftUI

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941)
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)

/// One trophy card — the domain Achievement plus a display icon and its
/// unlocked state (evaluated by the core AchievementEngine).
struct TrophyItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let details: String
    let unlocked: Bool
}

struct TrophySheet: View {
    let trophies: [TrophyItem]

    private var unlocked: Int { trophies.filter(\.unlocked).count }
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Трофеи").font(.title2.bold()).foregroundStyle(ink)
                Text("\(unlocked) из \(trophies.count)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 22).padding(.bottom, 16)

            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(trophies) { card($0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func card(_ t: TrophyItem) -> some View {
        VStack(spacing: 8) {
            Text(t.icon)
                .font(.system(size: 40))
                .grayscale(t.unlocked ? 0 : 1)
                .opacity(t.unlocked ? 1 : 0.45)
            Text(t.title)
                .font(.subheadline.bold())
                .foregroundStyle(t.unlocked ? ink : .secondary)
                .multilineTextAlignment(.center)
            Text(t.details)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(t.unlocked ? accent.opacity(0.14) : Color(.systemGray6))
        )
        .overlay(alignment: .topTrailing) {
            if t.unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accent)
                    .padding(10)
            }
        }
    }
}
