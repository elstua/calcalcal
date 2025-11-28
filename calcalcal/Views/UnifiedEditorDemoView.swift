// This demo view is only available in DEBUG builds and previews
#if DEBUG
import SwiftUI
import UIKit

#if DEBUG
struct UnifiedEditorDemoView: View {
    @State private var blocks: [Block] = [
        Block(type: .text("Welcome to the Unified Text Editor!"), calorieData: nil),
        Block(type: .text("This is a paragraph that acts as a block. Each paragraph is automatically treated as a separate block with spacing."), calorieData: nil),
        Block(type: .text("You can type naturally and press Enter to create new blocks. The editor maintains a continuous text flow while preserving block structure."), calorieData: nil),
        Block(type: .text("Try editing this text and see how the blocks update automatically!"), calorieData: nil)
    ]
    
    @State private var showingCalorieInput = false
    @State private var selectedBlockLocation = 0
    @State private var showGalleryOverlay = false
    @State private var selectedGalleryImage: UIImage? = nil
    @State private var overlayImageFrame: CGRect? = nil
    @State private var destinationFrame: CGRect? = nil
    @State private var isAnimatingImage = false
    @State private var imageMap: [UUID: UIImage] = [:]
    @State private var debugLastAction: String = ""
    @State private var debugLastImageUUID: UUID? = nil
    @State private var debugLastTextFlow: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Debug Info Overlay
                
                // Editor Header
                HStack {
                    Text("Block-Based Editor")
                        .font(.headline)
                    
                    Spacer()
                    
                    
                    Button(action: { addImageBlock() }) {
                        Label("Add Image", systemImage: "photo")
                    }
                    
                    
                    Button(action: { showGalleryOverlay = true }) {
                        Label("Gallery", systemImage: "photo.on.rectangle")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
                
                // Block Editor V2
                BlockEditorRepresentable(
                    blocks: $blocks,
                    imageMap: imageMap,
                    onBlocksChange: { updatedBlocks in
                        print("Blocks changed: \(updatedBlocks.count) blocks")
                        self.debugLastAction = "onBlocksChange"
                    }
                )
                
                // Bottom Toolbar
                HStack {
                    Button(action: { showBlockInfo() }) {
                        Image(systemName: "info.circle")
                    }
                    
                    Spacer()
                    
                    Text("Blocks: \(blocks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { clearAllText() }) {
                        Image(systemName: "trash")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
            .navigationTitle("Unified Editor Demo")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(
                ZStack {
                    if showGalleryOverlay {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { showGalleryOverlay = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            Spacer()
                        }
                        GalleryView(onImageTap: { uiImage, frame in
                            let randomCalories = Int.random(in: 50...600)
                            let calorieString = "\(randomCalories) kcal"
                            debugLastAction = "Add Image (gallery)"
                            let newUUID = UUID()
                            debugLastImageUUID = newUUID
                            // Use the new imageText block type with placeholder text
                            let newBlock = Block(type: .imageText(uiImage.pngData()!, newUUID, "Enter description..."), calorieData: calorieString)
                            self.blocks.append(newBlock)
                            self.imageMap[newUUID] = uiImage

                            selectedGalleryImage = uiImage
                            overlayImageFrame = frame
                            showGalleryOverlay = false
                            isAnimatingImage = true
                            print("[DEBUG] Gallery image selected")
                        })
                        .frame(maxHeight: 400)
                        .background(Color.clear)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func countBlocks() -> Int {
        return blocks.count
    }
    
    private func showBlockInfo() {
        print("=== Block Information ===")
        for (index, block) in blocks.enumerated() {
             print("Block \(index + 1): \(block)")
        }
        print("Total blocks: \(blocks.count)")
    }
    
    private func addSampleBlock() {
        let sampleTexts = [
            "This is a new block added programmatically.",
            "Here's another block with some sample content.",
            "Blocks can contain multiple lines\nlike this one does!",
            "Each block maintains its own spacing and formatting."
        ]
        let randomText = sampleTexts.randomElement() ?? ""
        let randomCalories = Int.random(in: 50...600)
        let calorieString = "\(randomCalories) kcal"
        
        let newBlock = Block(type: .text(randomText), calorieData: calorieString)
        self.blocks.append(newBlock)
    }
    
    private func addImageBlock() {
        let randomCalories = Int.random(in: 50...600)
        let calorieString = "\(randomCalories) kcal"
        if let image = UIImage(systemName: "photo") {
            let newUUID = UUID()
            // Use the new imageText block type with placeholder text
            let newBlock = Block(type: .imageText(image.pngData()!, newUUID, "Enter description..."), calorieData: calorieString)
            self.blocks.append(newBlock)
            self.imageMap[newUUID] = image
            debugLastAction = "Add Image (button)"
            debugLastImageUUID = newUUID
        }
    }
    
    private func clearAllText() {
        blocks.removeAll()
        imageMap.removeAll()
        debugLastAction = "Clear All Text"
        debugLastImageUUID = nil
        debugLastTextFlow = ""
        print("[DEBUG] Cleared all text")
    }
}

// MARK: - Preview

struct UnifiedEditorDemoView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedEditorDemoView()
    }
}
#endif

extension Image {
    func asUIImage() -> UIImage? {
        // Try to extract UIImage from SwiftUI Image (only works for system or asset images)
        let mirror = Mirror(reflecting: self)
        if let provider = mirror.descendant("provider") {
            let providerMirror = Mirror(reflecting: provider)
            if let uiImage = providerMirror.descendant("base") as? UIImage {
                return uiImage
            }
        }
        return nil
    }
}
#endif

