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
    
    private let batchSize = 50
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Callback for when an image is tapped, passing the image and its global frame
    var onImageTap: ((UIImage, CGRect) -> Void)?
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(photoAssets.indices, id: \.self) { idx in
                    GeometryReader { geo in
                        ImageComponent(
                            asset: photoAssets[idx],
                            uiImage: nil,
                            isLarge: false,
                            onDelete: nil,
                            onLongPress: { image in
                                selectedImage = image
                                showLargeImage = true
                            }
                        )
                        .onTapGesture {
                            // Load the image for tap callback
                            let imageManager = PHCachingImageManager()
                            let options = PHImageRequestOptions()
                            options.deliveryMode = .highQualityFormat
                            options.isSynchronous = true
                            imageManager.requestImage(
                                for: photoAssets[idx],
                                targetSize: CGSize(width: 300, height: 300),
                                contentMode: .aspectFill,
                                options: options
                            ) { image, _ in
                                if let image = image {
                                    let frame = geo.frame(in: .global)
                                    onImageTap?(image, frame)
                                }
                            }
                        }
                    }
                    .frame(height: 130)
                    .onAppear {
                        // Trigger loading next batch when approaching the end
                        if idx >= photoAssets.count - 10 {
                            loadNextBatch()
                        }
                    }
                }
            }
            .padding()
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
                .background(Color.black.opacity(0.7).ignoresSafeArea())
            }
        }
        .alert(isPresented: $photoAccessDenied) {
            Alert(title: Text("Photo Access Denied"), message: Text("Please allow photo access in Settings to view your gallery."), dismissButton: .default(Text("OK")))
        }
    }
    
    private func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized || status == .limited {
            fetchPhotos()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    fetchPhotos()
                } else {
                    photoAccessDenied = true
                }
            }
        } else {
            photoAccessDenied = true
        }
    }
    
    private func fetchPhotos() {
        // Fetch all asset references (lightweight - no actual images loaded)
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
        
        // Check if we've already loaded all assets
        guard currentCount < totalCount else { return }
        
        isLoadingMore = true
        
        // Calculate how many assets to load in this batch
        let remainingCount = totalCount - currentCount
        let loadCount = min(batchSize, remainingCount)
        
        // Extract the next batch of assets
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

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
} 
