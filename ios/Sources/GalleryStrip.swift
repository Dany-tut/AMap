import SwiftUI
import Photos

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941)

/// Loads recent photo-library thumbnails and resolves full-resolution data on tap.
@MainActor
final class GalleryModel: ObservableObject {
    struct Thumb: Identifiable { let id: String; let image: UIImage; let asset: PHAsset }

    @Published var thumbs: [Thumb] = []
    @Published var denied = false

    private let imageManager = PHImageManager.default()

    func load() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                guard status == .authorized || status == .limited else {
                    self?.denied = true; return
                }
                self?.fetch()
            }
        }
    }

    private func fetch() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 12
        let assets = PHAsset.fetchAssets(with: .image, options: opts)

        let target = CGSize(width: 220, height: 220)
        let req = PHImageRequestOptions()
        req.deliveryMode = .opportunistic
        req.resizeMode = .fast

        assets.enumerateObjects { [weak self] asset, _, _ in
            self?.imageManager.requestImage(for: asset, targetSize: target,
                                            contentMode: .aspectFill, options: req) { img, _ in
                guard let img else { return }
                Task { @MainActor in
                    guard let self else { return }
                    if !self.thumbs.contains(where: { $0.id == asset.localIdentifier }) {
                        self.thumbs.append(.init(id: asset.localIdentifier, image: img, asset: asset))
                    }
                }
            }
        }
    }

    /// Full-resolution JPEG data for a picked asset.
    func fullData(for asset: PHAsset, _ completion: @escaping (Data) -> Void) {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        imageManager.requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
            guard let data else { return }
            Task { @MainActor in completion(data) }
        }
    }
}

/// Horizontal strip of recent gallery photos beneath the camera zone. The last
/// tile opens the full system picker.
struct GalleryStrip: View {
    @StateObject private var model = GalleryModel()
    let onPick: (Data) -> Void
    let onMore: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.thumbs) { thumb in
                    Button { model.fullData(for: thumb.asset, onPick) } label: {
                        Image(uiImage: thumb.image)
                            .resizable().scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                Button(action: onMore) {
                    VStack(spacing: 3) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 17))
                        Text("Все").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.12)))
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 58)
        .onAppear { model.load() }
    }
}
