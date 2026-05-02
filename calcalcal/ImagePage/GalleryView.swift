
import SwiftUI
import UIKit
import Photos

struct GalleryView: View {
    @State private var photoAssets: [PHAsset] = []
    @State private var allAssets: PHFetchResult<PHAsset>?
    @State private var isLoadingMore = false
    @State private var selectedImage: UIImage? = nil
    @State private var showLargeImage = false
    @State private var photoAccessDenied = false
    @State private var thumbnailFrames: [String: CGRect] = [:]

    private let batchSize = 50

    /// Display configuration (editor vs picker)
    var config: GalleryDisplayConfig = .editor

    /// Namespace for matched geometry transitions (optional)
    var geometryNamespace: Namespace.ID? = nil

    /// Callback for when an image is tapped, passing the image and its global frame
    var onImageTap: ((UIImage, CGRect) -> Void)?

    /// Callback with PHAsset identifier and source frame for matched geometry (optional)
    var onImageTapWithId: ((UIImage, String, CGRect) -> Void)?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: config.gridItems, spacing: config.rowSpacing) {
                ForEach(photoAssets, id: \.localIdentifier) { asset in
                    thumbnailCell(for: asset)
                        .onAppear {
                            if asset == photoAssets.last || photoAssets.suffix(10).contains(asset) {
                                loadNextBatch()
                            }
                        }
                }
            }
            .padding(config.contentPadding)
        }
        .onAppear(perform: loadPhotos)
        .sheet(isPresented: $showLargeImage) {
            if let selectedImage = selectedImage {
                VStack {
                    Spacer()
                    ImageComponent(
                        asset: nil,
                        uiImage: selectedImage,
                        isLarge: true,
                        onDelete: nil,
                        onLongPress: nil
                    )
                    Spacer()
                }
                .background(DSColors.overlayHeavy.ignoresSafeArea())
            }
        }
        .alert(isPresented: $photoAccessDenied) {
            Alert(
                title: Text("Photo Access Denied"),
                message: Text("Please allow photo access in Settings to view your gallery."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Thumbnail cell

    @ViewBuilder
    private func thumbnailCell(for asset: PHAsset) -> some View {
        let assetId = asset.localIdentifier

        ImageComponent(
            asset: asset,
            uiImage: nil,
            config: config,
            onDelete: nil,
            onLongPress: { image in
                selectedImage = image
                showLargeImage = true
            }
        )
        .aspectRatio(config.cardAspectRatio ?? 1, contentMode: .fit)
        .modifier(OptionalMatchedGeometry(id: assetId, namespace: geometryNamespace))
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        thumbnailFrames[assetId] = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { newFrame in
                        thumbnailFrames[assetId] = newFrame
                    }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap(asset: asset, id: assetId)
        }
    }

    // MARK: - Tap handling (async)

    private func handleTap(asset: PHAsset, id: String) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        PHCachingImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 600, height: 600),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let image = image else { return }
            DispatchQueue.main.async {
                let sourceFrame = thumbnailFrames[id] ?? .zero
                onImageTapWithId?(image, id, sourceFrame)
                onImageTap?(image, sourceFrame)
            }
        }
    }

    // MARK: - Photo loading

    private func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized || status == .limited {
            fetchPhotos()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    fetchPhotos()
                } else {
                    DispatchQueue.main.async { photoAccessDenied = true }
                }
            }
        } else {
            photoAccessDenied = true
        }
    }

    private func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        DispatchQueue.main.async {
            self.allAssets = assets
            self.loadNextBatch()
        }
    }

    private func loadNextBatch() {
        guard let allAssets = allAssets, !isLoadingMore else { return }

        let currentCount = photoAssets.count
        let totalCount = allAssets.count
        guard currentCount < totalCount else { return }

        isLoadingMore = true
        let loadCount = min(batchSize, totalCount - currentCount)

        var newAssets: [PHAsset] = []
        for i in currentCount..<(currentCount + loadCount) {
            newAssets.append(allAssets.object(at: i))
        }

        DispatchQueue.main.async {
            self.photoAssets.append(contentsOf: newAssets)
            self.isLoadingMore = false
        }
    }
}

// MARK: - Optional matched geometry modifier

private struct OptionalMatchedGeometry: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let ns = namespace {
            content.matchedGeometryEffect(id: id, in: ns)
        } else {
            content
        }
    }
}

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView(config: .picker)
    }
}
