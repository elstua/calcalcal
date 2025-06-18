import SwiftUI
import UIKit

struct UnifiedEditorDemoView: View {
    @State private var editorText = """
    Welcome to the Unified Text Editor!
    This is a paragraph that acts as a block. Each paragraph is automatically treated as a separate block with spacing.
    You can type naturally and press Enter to create new blocks. The editor maintains a continuous text flow while preserving block structure.
    Try editing this text and see how the blocks update automatically!
    """
    
    @State private var showingCalorieInput = false
    @State private var selectedBlockLocation = 0
    @StateObject private var editorProxy = UnifiedTextEditorProxy()
    @State private var showGalleryOverlay = false
    @State private var selectedGalleryImage: UIImage? = nil
    @State private var overlayImageFrame: CGRect? = nil
    @State private var destinationFrame: CGRect? = nil
    @State private var isAnimatingImage = false
    @State private var imageMap: [UUID: UIImage] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                
                // Unified Text Editor
                UnifiedTextEditor(text: $editorText, imageMap: imageMap)
                    .blockSpacing(20)
                    .proxy(editorProxy)
                    .onTextChange { text in
                        print("Text changed: \(text.count) characters")
                    }
                
                // Bottom Toolbar
                HStack {
                    Button(action: { showBlockInfo() }) {
                        Image(systemName: "info.circle")
                    }
                    
                    Spacer()
                    
                    Text("Blocks: \(countBlocks())")
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
                            let uuid = UUID()
                            imageMap[uuid] = uiImage
                            editorProxy.addImageBlock(imageReference: uuid)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let textView = editorProxy.textView {
                                    editorText = textView.text
                                }
                            }
                            selectedGalleryImage = uiImage
                            overlayImageFrame = frame
                            showGalleryOverlay = false
                            isAnimatingImage = true
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
        // Use the actual text view's block analysis if available
        if let textView = editorProxy.textView {
            let analysis = textView.getBlockAnalysis()
            return analysis.totalBlocks
        }
        
        // Fallback to simple paragraph counting
        let paragraphs = editorText.components(separatedBy: "\n\n")
        return paragraphs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
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
        editorProxy.addTextBlock(randomText, calorieData: calorieString)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let textView = editorProxy.textView {
                editorText = textView.text
            }
        }
    }
    
    private func addImageBlock() {
        let uuid = UUID()
        // No image added to imageMap, so UIKit will show the placeholder
        let randomCalories = Int.random(in: 50...600)
        let calorieString = "\(randomCalories) kcal"
        editorProxy.addImageBlock(imageReference: uuid, calorieData: calorieString)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let textView = editorProxy.textView {
                editorText = textView.text
            }
        }
    }
    
    private func showBlockInfo() {
        let blocks = editorText.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        print("=== Block Information ===")
        for (index, block) in blocks.enumerated() {
            print("Block \(index + 1): \(block.prefix(50))...")
        }
        print("Total blocks: \(blocks.count)")
    }
    
    private func clearAllText() {
        editorText = ""
    }
    
    private func debugBlocks() {
        print("\n🐞 DEBUG BLOCKS REQUESTED")
        
        // Print analysis from the actual text view
        if let textView = editorProxy.textView {
            textView.printBlockAnalysis()
        } else {
            print("❌ No text view available in proxy")
        }
        
        // Also show the SwiftUI binding text analysis
        print("SwiftUI Binding Text Analysis:")
        print("  Full text length: \(editorText.count)")
        print("  Number of \\n\\n separators: \(editorText.components(separatedBy: "\n\n").count - 1)")
        
        let paragraphs = editorText.components(separatedBy: "\n\n")
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                print("  SwiftUI Paragraph \(index + 1): '\(trimmed.prefix(50))...'")
            } else {
                print("  SwiftUI Paragraph \(index + 1): [EMPTY]")
            }
        }
    }
}

// MARK: - Preview

struct UnifiedEditorDemoView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedEditorDemoView()
    }
}

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
