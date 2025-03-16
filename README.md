# CalCalCal

CalCalCal is a calorie tracker IOS that count everything in notes-like interface from user prompt by the help of llm. On the left side of the input we show the written text or photos from the user, on the right side we show  calories counted for this paragraph. New paragraph = new calorie count

## Key Concept: Line-based Layout Manager
The CalCalCal app uses a flexible Line-based Layout Manager system to synchronize text input with calorie calculations. This approach offers several advantages:


### How Calorie Input Works

**Unified Writing Experience**: The app provides a single, cohesive text area where users can type naturally, paste multiple paragraphs, and navigate with standard text editing gestures.
Paragraph-Level Calorie Tracking: Behind the scenes, the app automatically breaks the text into logical paragraphs and calculates calories for each one individually.
Real-Time Calculation: As users type, the app analyzes their food descriptions and displays calorie estimates in real-time, positioned alongside the corresponding text.
Image Integration: Users can add food images, which are analyzed to estimate calories using vision-capable LLMs.

# Technical Structure

### Custom Text Editor Implementation
At the heart of CalCalCal is a custom text editor built with a UIKit-SwiftUI hybrid approach:
1. CalorieTextView (UIKit): A specialized UITextView subclass that handles:
    - Paragraph detection and management
    - Positioning calorie counts beside paragraphs
    - Text layout and rendering
2. CalorieTextEditor (SwiftUI Wrapper): A SwiftUI component that wraps the UIKit text view and:
    - Synchronizes text content with SwiftUI state
    - Manages editing events and focus
    - Connects with calorie calculation services
3. ParagraphInfo Model: A data structure that:
    - Tracks text ranges, content, and calorie information for each paragraph
    - Maintains the relationship between text and its corresponding calorie count

## Paragraph Processing Pipeline
When a user types or edits text, the following processes occur:
1. Text Change Detection: The text view monitors changes to its content
2. Paragraph Detection: The text is parsed into logical paragraphs using native iOS text handling
3. Paragraph Mapping: Each paragraph is matched with any existing paragraphs to preserve calorie data
4. Calorie Calculation: New or modified paragraphs are sent to the calorie calculation service
5. Visual Update: Calorie labels are positioned and displayed beside their corresponding paragraphs


#  project structure
CalCalCal/
├── App/
│   └── calcalcalApp.swift
├── Models/
│   └── ParagraphInfo.swift -- Data model for storing paragraph text and calorie information
├── Views/
│   ├── ContentView.swift -- Main app view with text editor and total calorie display
│   └── Components/
│       ├── AddButton.swift
│       └── ImagePickerView.swift
├── Editor/
│   ├── CalorieTextView.swift -- Custom UIKit text view with paragraph tracking and calorie display
│   └── CalorieTextEditor.swift -- SwiftUI wrapper for the custom text view
└── Services/
    └── CalorieCalculationService.swift

### Flow of Information
1. User types in the CalorieTextEditor
2. Text changes are detected by CalorieTextView
3. Text is parsed into paragraphs
4. Each paragraph is sent to CalorieCalculationService
5. Calculated calories are displayed next to corresponding paragraphs
6. Total calories are summed and displayed at the bottom

## Development Setup

This project is built using:
- Swift and SwiftUI
- Xcode as the primary development environment
- Minimum iOS target (version information to be added)

## Technical Implementation Insights

### Paragraph Detection
The app uses `NSString.enumerateSubstrings(in:options:using:)` with the `.byParagraphs` option to intelligently split text into logical paragraphs. This approach respects standard line breaks and paragraph formatting.
``` nsText.enumerateSubstrings(in: fullRange, options: .byParagraphs) { (substring, substringRange, _, _) in
    if substring != nil {
        paragraphRanges.append(substringRange)
    }
}```

### Calorie Display Positioning
Calorie labels are positioned by calculating the bounding rectangles of text paragraphs using the `NSLayoutManager:`
```let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph.range, actualCharacterRange: nil)
var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)```
 

### Efficient Updates
The app optimizes performance by:
- Tracking which paragraphs have changed
- Only recalculating calories for modified paragraphs
- Reusing calorie information for unchanged paragraphs
- Caching calculation results to avoid redundant processing