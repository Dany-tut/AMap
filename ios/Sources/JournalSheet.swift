import SwiftUI
import AMapsDomain

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941)
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)

/// Journal — memories (photo/note per place) and ride history, newest first.
/// Both are driven by `AppModel`.
struct JournalSheet: View {
    @ObservedObject var model: AppModel

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    private var isEmpty: Bool { model.journal.isEmpty && model.sessions.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Дневник").font(.title2.bold()).foregroundStyle(ink)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 22).padding(.bottom, 16)

            if isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !model.journal.isEmpty {
                            section("Места")
                            ForEach(model.journal) { memoryCard($0) }
                        }
                        if !model.sessions.isEmpty {
                            section("Поездки").padding(.top, model.journal.isEmpty ? 0 : 8)
                            ForEach(model.sessions) { rideCard($0) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var subtitle: String {
        isEmpty ? "Пока пусто"
                : "\(model.journal.count) мест · \(model.sessions.count) поездок"
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "book")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(accent.opacity(0.6))
            Text("Дневник пуст")
                .font(.headline).foregroundStyle(ink)
            Text("Проезжай мимо мест во время поездки —\nкарта предложит прикрепить фото и заметку.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func memoryCard(_ m: Memory) -> some View {
        HStack(spacing: 14) {
            if let data = m.photo, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text(m.emoji)
                    .font(.system(size: 26))
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.14)))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(m.placeName).font(.subheadline.bold()).foregroundStyle(ink)
                if let note = m.note {
                    Text(note).font(.caption).foregroundStyle(ink.opacity(0.8))
                        .lineLimit(2)
                } else {
                    Text("Фото").font(.caption).foregroundStyle(.secondary)
                }
                Text(Self.dateFmt.string(from: m.createdAt))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6)))
    }

    private func rideCard(_ s: Session) -> some View {
        HStack(spacing: 14) {
            Text(s.activity.emoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Circle().fill(accent.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(s.activity.label)
                    .font(.subheadline.bold()).foregroundStyle(ink)
                Text(Self.dateFmt.string(from: s.startedAt))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    stat("\(km(s)) км")
                    stat("+\(s.newCellsOpened) ячеек")
                    if let d = duration(s) { stat(d) }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6)))
    }

    private func stat(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(accent)
    }

    private func km(_ s: Session) -> String {
        (s.distanceMeters / 1000).formatted(.number.precision(.fractionLength(1)))
    }

    private func duration(_ s: Session) -> String? {
        guard let end = s.endedAt else { return nil }
        let mins = Int(end.timeIntervalSince(s.startedAt) / 60)
        guard mins > 0 else { return nil }
        return mins >= 60 ? "\(mins / 60) ч \(mins % 60) мин" : "\(mins) мин"
    }
}
