# Block Counting and Position Analysis

## Overview

This document explains how blocks are counted and positioned in the Unified Text Editor, and how to debug issues where paragraphs don't get green backgrounds (indicating they're not being counted as text blocks).

## How Block Counting Works

### 1. Paragraph Detection
The system uses `NSString.enumerateSubstrings(options: [.byParagraphs, .localized])` to detect paragraph boundaries. Each paragraph can potentially become a block.

### 2. Block Metadata Assignment
For a paragraph to be considered a "block" and get a green background, it must:
- Have non-empty content (after trimming whitespace and newlines)
- Have `BlockMetadata` assigned to it in the `UnifiedTextContentStorage`

### 3. Background Color Logic
Green backgrounds are applied in `updateBlockBackgroundAppearance()`:
```swift
case .text:
    // Green tint for text blocks
    view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.05)
case .imageText:
    // Blue tint for image blocks  
    view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
```

## Common Issues

### Issue 1: Missing Green Backgrounds
**Symptom**: Some paragraphs don't have green backgrounds
**Cause**: The paragraph doesn't have `BlockMetadata` assigned
**Solution**: The `updateParagraphBlocks()` method should auto-assign metadata

### Issue 2: Inconsistent Block Counting
**Symptom**: Block count in UI doesn't match visible blocks
**Cause**: Different counting methods between SwiftUI binding and actual text view
**Solutions**: 
- Use `UnifiedTextView.getBlockAnalysis()` for accurate counting
- The demo view now uses the text view's analysis when available

### Issue 3: Block Position Calculation
**Symptom**: Can't determine which block a cursor/location is in
**Solution**: Use `getBlockPosition(at location: Int)` method

## Debugging Tools

### 1. Block Analysis Method
```swift
let analysis = textView.getBlockAnalysis()
// Returns: (totalBlocks: Int, textBlocks: Int, imageBlocks: Int, details: [String])
```

### 2. Debug Print Method
```swift
textView.printBlockAnalysis()
```
This prints detailed information about:
- Total block counts by type
- Each paragraph's status (has metadata or not)
- Paragraph ranges and content preview

### 3. Debug Button in Demo
The demo view now has a "Debug" button (🐞) that:
- Calls `printBlockAnalysis()` on the text view
- Shows comparison between SwiftUI binding text and actual text view content
- Prints detailed paragraph analysis

## Block Position Calculation

### Current Implementation
Blocks are positioned based on their order among non-empty paragraphs:

```swift
func getBlockPosition(at location: Int) -> Int? {
    var blockPosition = 0
    // Enumerate paragraphs, incrementing position for non-empty ones
    // Return position when location falls within a paragraph range
}
```

### Position vs Range
- **Position**: 1-based index among visible blocks (1, 2, 3...)
- **Range**: Character range in the text storage (location, length)

## Metadata Assignment Process

### Auto-Assignment in updateParagraphBlocks()
1. Clean up orphaned metadata from deleted paragraphs
2. Enumerate all paragraphs
3. For each non-empty paragraph without metadata:
   - Create default `BlockMetadata` with type `.text`
   - Assign it to the paragraph range
4. Force a second pass to ensure no paragraphs were missed
5. Log all assignments for debugging

### Manual Assignment
When adding blocks programmatically:
```swift
textView.addTextBlock("Content")  // Assigns .text metadata
textView.addImageBlock("Content") // Assigns .imageText metadata
```

## Verification Steps

To verify block counting is working correctly:

1. **Use Debug Button**: Press the 🐞 button in demo to see detailed analysis
2. **Check Console**: Look for auto-assignment logs like:
   ```
   📝 Auto-assigned text block metadata to paragraph at 0-50: 'Welcome to the Unified Text...'
   ```
3. **Visual Inspection**: All non-empty paragraphs should have green or blue backgrounds
4. **Count Verification**: Block count in UI should match visible blocks

## Expected Behavior

- Every non-empty paragraph should automatically get block metadata
- Block count should accurately reflect visible paragraphs with content
- Green backgrounds should appear for all text blocks
- Blue backgrounds should appear for image-text blocks
- Position calculation should correctly identify block order

## Troubleshooting

If blocks aren't getting green backgrounds:
1. Check console for metadata assignment logs
2. Use debug button to see which paragraphs lack metadata
3. Verify `updateParagraphBlocks()` is being called after text changes
4. Check if paragraph enumeration is finding the content correctly

### Block Sizing and Positioning Issues

**Problem**: Block backgrounds appear too small (single line) or positioned incorrectly
**Cause**: The `boundingRect(for characterRange: NSRange)` method was using simplified estimation
**Solution**: Improved the method to:
- Use TextKit 1 for accurate measurements when needed
- Calculate actual paragraph height using `NSAttributedString.boundingRect`
- Properly position blocks by measuring all preceding text
- Handle multi-line paragraphs correctly

**Debug Output**: The enhanced `printBlockAnalysis()` now shows:
```
📐 Block at 0-50:
   Type: text
   Content: 'Welcome to the Unified Text Editor!...'
   Lines: 1
   Frame: (0.0, 0.0, 343.0, 19.0)
   Text Length: 49 chars
```

This helps verify that:
- Frame height matches content (not just single line height)
- Frame positioning is accurate relative to other blocks
- Multi-line content gets appropriate height

## Immediate Update Strategy

### Problem with Delayed Updates
Previously, block information updates were inconsistent and delayed, causing:
- Visual lag when typing
- Bugs with missing block backgrounds
- Inconsistencies between text content and block metadata
- Slower updates on adding characters vs deleting

### Solution: Immediate Updates on Every Change
Now block information updates on **every single character change**:

#### Text Storage Delegate Updates
```swift
func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
    // Update blocks immediately on EVERY character change
    // This prevents bugs caused by delayed updates
}
```

#### Text View Delegate Updates  
```swift
func textViewDidChange(_ textView: UITextView) {
    // Update paragraph blocks immediately on every change
    updateParagraphBlocks()
    
    // Force immediate redraw and layout updates
    layoutIfNeeded()
}
```

### Performance Optimizations

#### Throttling for Rapid Changes
- Updates limited to ~60fps (0.016s intervals)
- Intelligent throttling skips rapid intermediate states
- Delayed update ensures final state is captured

#### Smart Change Detection
- Block structure hashing prevents unnecessary work
- Only updates when content actually changes
- Skips visual updates when structure is identical

#### Force Updates for Critical Operations
```swift
forceUpdateParagraphBlocks() // Bypasses throttling
```
Used for:
- Programmatically added blocks
- Critical state changes
- User-initiated operations

### Debug Output
Console logs show update frequency and throttling:
```
🔄 updateParagraphBlocks called at 123.456
⏰ Throttling update - too frequent (0.008s since last)
✅ Block structure unchanged - skipping update  
🔧 Block structure changed - performing full update
🚀 Force update - bypassing throttling
``` 