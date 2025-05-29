# CalCalCal TextKit 2 Unified Editor Specification

## Overview

A truly unified text editor using TextKit 2 that maintains block structure within a single UITextView. Each paragraph acts as a block with its own layout and spacing, supporting text blocks and image-text blocks with horizontal layout.

## Core Architecture

### Foundation: Custom NSTextContentStorage

The key is using TextKit 2's `NSTextContentStorage` which allows us to define custom paragraph layouts while maintaining a single text flow.

```
NSTextContentStorage (Document Model)
    ↓
NSTextLayoutManager (Custom Layout)
    ↓
NSTextContainer (View Container)
    ↓
UITextView (User Interface)
```

## Implementation Phases

### Phase 1: Core Foundation

#### 1.1 Custom Text Content Storage
Create a custom `NSTextContentStorage` subclass that:
- Maintains paragraph metadata (block type, spacing, layout)
- Stores image references for image blocks
- Tracks calorie data per paragraph

#### 1.2 Custom Text Layout Manager
Extend `NSTextLayoutManager` to:
- Identify paragraph boundaries
- Apply custom spacing between paragraphs
- Reserve space for image-text layouts
- Position calorie labels

#### 1.3 Block Attribute System
Define custom attributes for paragraphs:
- `blockType`: text or image-text
- `blockSpacing`: vertical spacing after block
- `imageReference`: UUID for image blocks
- `calorieData`: calculated calories

### Phase 2: Text Block Implementation

#### 2.1 Paragraph as Block
Each paragraph automatically becomes a block:
- Natural paragraph breaks create block boundaries
- Custom paragraph spacing via layout manager
- Maintain continuous text editing experience

#### 2.2 Custom Text Layout Fragment
Create `NSTextLayoutFragment` subclass for text blocks:
- Standard text flow
- Custom inter-paragraph spacing
- Right-aligned calorie display area

#### 2.3 Paragraph Styling
Apply block-specific styling:
- Background colors/borders per block
- Custom insets per paragraph
- Visual separation while maintaining text flow

### Phase 3: Image-Text Block Implementation

#### 3.1 Image Layout Fragment
Create specialized `NSTextLayoutFragment` for image-text blocks:
- Reserve 30% width for image on left
- Flow text in remaining 70%
- Maintain baseline alignment

#### 3.2 Image Attachment Alternative
Instead of `NSTextAttachment`:
- Store image reference in paragraph attributes
- Custom layout fragment draws image
- Text flows naturally around reserved space

#### 3.3 Exclusion Path Approach
Use `NSTextContainer` exclusion paths:
- Calculate image bounds per paragraph
- Create exclusion rectangles
- Update on layout changes

## Technical Architecture Details

### Text Storage Structure
```
Paragraph 1: "Breakfast today" [blockType: text]
Paragraph 2: "[IMG:uuid]Apples and..." [blockType: image-text]
Paragraph 3: "Lunch was great" [blockType: text]
```

### Layout Manager Responsibilities
1. **Block Detection**: Identify paragraph ranges
2. **Space Calculation**: Add inter-block spacing
3. **Image Positioning**: Calculate image frames
4. **Text Flow**: Manage text around images
5. **Calorie Placement**: Position calorie labels

### Custom Text View
Subclass UITextView to:
- Handle image rendering in draw method
- Manage tap gestures on images
- Coordinate with layout manager
- Render calorie overlays

## Key Implementation Strategies

### Block Identification
- Use paragraph breaks as natural block boundaries
- Store block metadata in paragraph attributes
- Layout manager reads attributes during layout

### Image Handling
- Images are NOT embedded in text
- Store image reference in attributes
- Layout manager reserves space
- Text view draws images in reserved areas

### Continuous Editing
- Single text storage maintains all text
- Cursor moves naturally between blocks
- Selection works across all content
- Native copy/paste preserved

### Performance Optimization
- Images drawn only when visible
- Layout fragments cached
- Incremental layout updates
- Efficient attribute storage

## Advantages of This Approach

1. **True Unified Experience**: Single text view with natural cursor movement
2. **Native Performance**: Uses iOS text system directly
3. **Block Structure**: Maintains block concept within unified text
4. **Future Proof**: TextKit 2 is Apple's modern text framework
5. **Flexibility**: Easy to add new block types

## Implementation Complexity

### Easy Parts
- Basic paragraph spacing
- Text block styling
- Calorie label positioning

### Moderate Parts
- Custom layout fragments
- Image space reservation
- Block attribute system

### Challenging Parts
- Image-text horizontal layout
- Performance with many images
- Complex gesture handling

## Success Criteria

- Cursor moves freely between all blocks
- Text selection works across entire document
- Images appear inline with 30/70 layout
- Editing feels like single text area
- Performance remains smooth with 100+ blocks

## Future Extensions

1. **More Block Types**: Code blocks, quotes, lists
2. **Rich Text**: Bold, italic within blocks
3. **Interactive Elements**: Checkboxes, toggles
4. **Nested Blocks**: Indentation, hierarchies
5. **Custom Layouts**: Beyond 30/70 splits