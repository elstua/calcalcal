import SwiftUI
import UIKit
import Photos

struct GalleryView: View {
    @State private var images: [UIImage] = []
    @State private var selectedImage: UIImage? = nil
    @State private var showLargeImage = false
    @State private var photoAccessDenied = false
    
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
                ForEach(images.indices, id: \ .self) { idx in
                    GeometryReader { geo in
                        ImageComponent(
                            uiImage: images[idx],
                            isLarge: false,
                            onDelete: nil,
                            onLongPress: {
                                selectedImage = images[idx]
                                showLargeImage = true
                            }
                        )
                        .onTapGesture {
                            let frame = geo.frame(in: .global)
                            onImageTap?(images[idx], frame)
                        }
                    }
                    .frame(height: 130)
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
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let imageManager = PHCachingImageManager()
        var uiImages: [UIImage] = []
        let targetSize = CGSize(width: 300, height: 300)
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        assets.enumerateObjects { asset, _, _ in
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                if let image = image {
                    uiImages.append(image)
                }
            }
        }
        DispatchQueue.main.async {
            self.images = uiImages
        }
    }
}

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
} 
