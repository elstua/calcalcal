# Unified Text Editor Implementation

## Overview

This implementation provides a unified text editor that maintains block structure within a single UITextView. Each paragraph acts as a block with its own layout and spacing, using custom drawing and metadata management.

## Core Components

### 1. UnifiedTextContentStorage
- Custom class for managing block metadata
- Maintains paragraph metadata (block type, spacing, calorie data)
- Manages block attributes and updates
- Works with standard NSTextStorage

### 2. UnifiedTextLayoutManager
- Helper class for layout calculations
- Handles block spacing calculations
- Manages calorie label drawing

### 3. UnifiedTextView
- Custom `UITextView` subclass
- Uses standard UIKit text system with custom drawing
- Handles block background drawing and visual separation
- Provides block management APIs

### 4. UnifiedTextEditor
- SwiftUI wrapper for UnifiedTextView
- Enables use in SwiftUI applications
- Provides view modifiers for configuration

## Features Implemented

### Phase 1: Core Foundation ✅
- [x] Custom metadata storage system
- [x] Block spacing management
- [x] Block attribute system
- [x] SwiftUI integration

### Phase 2: Text Blocks ✅
- [x] Paragraph-based block structure
- [x] Custom block spacing (visual)
- [x] Visual block separation
- [x] Continuous editing experience
- [x] Calorie label support

### Phase 3: Image Support 🔄
- [ ] Image-text blocks (prepared for next phase)
- [ ] 30/70 horizontal layout
- [ ] Image attachment handling

## Technical Implementation

The implementation uses standard UIKit text system (TextKit 1) with custom drawing to achieve the block-based editing experience. This approach avoids the complexity and potential crashes of TextKit 2 while still providing the desired functionality.

### Architecture

```
UnifiedTextContentStorage (Metadata Management)
    ↓
UnifiedTextView (UITextView + Custom Drawing)
    ↓
UnifiedTextLayoutManager (Layout Helpers)
```

## Usage

### Basic Usage in SwiftUI

```swift
struct MyView: View {
    @State private var text = "Hello, World!"
    
    var body: some View {
        UnifiedTextEditor(text: $text)
            .blockSpacing(20)
            .onTextChange { newText in
                print("Text changed: \(newText)")
            }
    }
}
```

### Key Features

1. **Automatic Block Detection**: Paragraphs are automatically detected and treated as blocks
2. **Visual Separation**: Each block has subtle background and separator lines
3. **Custom Spacing**: Configurable spacing between blocks (visual)
4. **Continuous Editing**: Cursor moves naturally between blocks
5. **Native Performance**: Uses standard UIKit text system

## Implementation Details

- **Block Detection**: Uses NSString paragraph detection methods
- **Visual Spacing**: Achieved through custom drawing, not text layout
- **Metadata Storage**: Custom class manages block attributes
- **Calorie Labels**: Drawn as overlays on blocks

## Next Steps

1. **Image Support**: Implement image-text blocks with 30/70 layout
2. **Calorie Integration**: Connect calorie calculation system
3. **Block Interactions**: Add tap/long-press gestures for block actions
4. **Rich Text**: Add support for bold, italic, etc.
5. **Performance**: Optimize for large documents

## Demo

Run `UnifiedEditorDemoView` to see the editor in action. The demo includes:
- Sample text with multiple blocks
- Block counter
- Add/remove block functionality
- Visual block separation with spacing 