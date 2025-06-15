import SwiftUI

struct GalleryView: View {
    // Mock images for demonstration
    let images: [Image] = [
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image"),
        Image("sample_image")
    ]
    
    @State private var selectedImage: Image? = nil
    @State private var showLargeImage = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(images.indices, id: \.self) { idx in
                    ImageComponent(
                        image: images[idx],
                        isLarge: false,
                        onDelete: nil,
                        onLongPress: {
                            selectedImage = images[idx]
                            showLargeImage = true
                        }
                    )
                }
            }
            .padding()
        }
        .sheet(isPresented: $showLargeImage) {
            if let selectedImage = selectedImage {
                VStack {
                    Spacer()
                    ImageComponent(
                        image: selectedImage,
                        isLarge: true,
                        onDelete: nil,
                        onLongPress: nil
                    )
                    Spacer()
                }
                .background(Color.black.opacity(0.7).ignoresSafeArea())
            }
        }
    }
}

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
} 
