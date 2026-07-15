import SwiftUI
import PhotosUI

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941)
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)

/// "New place" card — shown when a ride passes a notable spot or the rider taps
/// «+ Заметка». A live camera zone captures on tap; a gallery strip below picks
/// a recent photo; the full system picker is one tap further. Photo and/or note
/// are filed into the journal.
struct PlaceCardSheet: View {
    let place: DemoPlace
    let onSave: (String?, Data?) -> Void
    let onSkip: () -> Void

    @StateObject private var camera = CameraCapture()
    @State private var note = ""
    @State private var photo: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false

    private var hasContent: Bool {
        photo != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            captureZone
            if photo == nil {
                GalleryStrip(onPick: { photo = $0 }, onMore: { showPicker = true })
            }

            noteField

            VStack(spacing: 10) {
                Button { onSave(note, photo) } label: {
                    Text("Сохранить в дневник")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(hasContent ? accent : accent.opacity(0.35)))
                        .foregroundStyle(.white)
                }
                .disabled(!hasContent)

                Button("Продолжить поездку", action: onSkip)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 6)
        }
        // Push content clear of the sheet's drag indicator.
        .padding(.top, 18)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .task(id: pickerItem) {
            if let data = try? await pickerItem?.loadTransferable(type: Data.self) {
                photo = data
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Новое место")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(accent.opacity(0.14)))
            Text("\(place.emoji) \(place.name)")
                .font(.title2.bold()).foregroundStyle(ink)
                .multilineTextAlignment(.center)
            Text(place.category)
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    /// Live camera preview; a tap anywhere captures the frame. Falls back to a
    /// prompt when no camera is available (Simulator / denied).
    private var captureZone: some View {
        ZStack {
            if let photo, let img = UIImage(data: photo) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(height: 176).clipped()
                    .overlay(alignment: .topTrailing) {
                        Button { self.photo = nil } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(9).background(Circle().fill(.black.opacity(0.4)))
                        }
                        .padding(8)
                    }
            } else if camera.available {
                CameraPreview(session: camera.session)
                    .frame(height: 176)
                    .overlay(alignment: .bottom) {
                        Circle().strokeBorder(.white, lineWidth: 4)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(.white.opacity(0.25)))
                            .padding(.bottom, 12)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { camera.capture { photo = $0 } }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "camera.fill").font(.system(size: 26))
                    Text(camera.denied ? "Нет доступа к камере" : "Камера недоступна")
                        .font(.subheadline.weight(.semibold))
                    Text("Выбери фото из галереи ниже")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity).frame(height: 176)
                .background(accent.opacity(0.10))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var noteField: some View {
        TextField("✏️ Заметка о месте…", text: $note, axis: .vertical)
            .lineLimit(2...4)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6)))
            .padding(.horizontal, 20)
    }
}
