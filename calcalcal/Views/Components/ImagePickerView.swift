import SwiftUI
import PhotosUI

struct ImagePickerView: View {
    @Binding var isPresented: Bool
    var onImageSelected: (UIImage) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack {
            Text("Add Food Image")
                .font(.headline)
                .padding()
            
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Select from Photo Library", systemImage: "photo")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .onChange(of: selectedItem) { newItem in
                if let newItem = newItem {
                    loadTransferable(from: newItem)
                }
            }
            
            Button("Cancel") {
                isPresented = false
            }
            .padding()
        }
        .padding()
        .frame(width: 300, height: 200)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    private func loadTransferable(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let imageData = data, let image = UIImage(data: imageData) {
                    onImageSelected(image)
                    DispatchQueue.main.async {
                        isPresented = false
                    }
                }
            case .failure(let error):
                print("Error loading image: \(error)")
            }
        }
    }
}

struct ImagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ImagePickerView(isPresented: .constant(true), onImageSelected: { _ in })
            .previewLayout(.sizeThatFits)
    }
}
