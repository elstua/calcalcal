# CalCalCal

CalCalCal is a calorie tracker IOS that count everything in notes-like interface from user prompt by the help of llm. On the left side of the input we show the written text or photos from the user, on the right side we show  calories counted for this paragraph. New paragraph = new calorie count

## Key Concept: Line-based Layout Manager
The CalCalCal app uses a flexible Line-based Layout Manager system to synchronize text input with calorie calculations. This approach offers several advantages:

### How It Works

- Line and Paragraph Tracking: The TextLineManager monitors the UITextView's layout in real-time, detecting both individual lines and logical paragraphs (groups of lines separated by newlines).
- Slot-based Architecture: Instead of hardcoding the calorie display, the app uses a "slot" system where different UI elements can be positioned alongside text. This makes it easy to add new features (like nutrition info or food photos) without changing the core layout logic.
- Precise Positioning: By directly accessing UIKit's text layout system, the app can accurately position calorie information next to the corresponding text, even when text wraps across multiple lines.
- Efficient Updates: Instead of recalculating everything when text changes, only the affected paragraphs are updated, improving performance.

## Project Structure

### Core Application Files
- `calcalcalApp.swift` - The main entry point of the application that sets up the SwiftUI app structure.
- `ContentView.swift` - The main view of the application that orchestrates the overall UI layout.

### Text Editing Components
- `FlexibleTextEditor.swift` - A custom text editor implementation that provides flexible editing capabilities.
- `TextViewRepresentable.swift` - UIKit text view wrapper for SwiftUI integration.
- `TextLineManager.swift` - Manages text lines and their associated data, handling text processing and calculations.
- `LineData.swift` - Data model for storing and managing individual line information.

### UI Components
- `SlotViewProvider.swift` - Provides slot view functionality for the calculator interface.
- `AddButton.swift` - Implementation of the add button component.
- `LayoutConstants.swift` - Contains constant values for UI layout and styling.

### Data Management
- `DocumentModel.swift` - Manages the document state and data persistence.

### Supporting Directories
- `Assets.xcassets/` - Contains app icons and other image assets.
- `Preview Content/` - Contains preview data for SwiftUI previews.

### Testing
- `calcalcalTests/` - Contains unit tests for the application.
- `calcalcalUITests/` - Contains UI tests for the application.

## Project Configuration
- `calcalcal.xcodeproj/` - Xcode project configuration files.
- `.vscode/` - Visual Studio Code configuration files.

## Development Setup

This project is built using:
- Swift and SwiftUI
- Xcode as the primary development environment
- Minimum iOS target (version information to be added)

## Getting Started

1. Clone the repository
2. Open `calcalcal.xcodeproj` in Xcode
3. Build and run the project

## Features

- Interactive text editing with calculation capabilities
- Flexible layout system
- Real-time calculations
- Custom UI components
- Document-based architecture

## Contributing

Feel free to submit issues and enhancement requests. 