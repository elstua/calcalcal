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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Editor Header
                HStack {
                    Text("Block-Based Editor")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { addSampleBlock() }) {
                        Label("Add Block", systemImage: "plus.circle")
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
                
                // Unified Text Editor
                UnifiedTextEditor(text: $editorText)
                    .blockSpacing(20)
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
                .background(Color(UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
            .navigationTitle("Unified Editor Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Helper Functions
    
    private func countBlocks() -> Int {
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
        editorText += "\n\n" + randomText
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
}

// MARK: - Preview

struct UnifiedEditorDemoView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedEditorDemoView()
    }
} 