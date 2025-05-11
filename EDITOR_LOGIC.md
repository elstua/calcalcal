# Editor Logic and File Structure

## 1. Overview

The editor allows users to input text, typically food items or meals. The system automatically calculates and displays calorie counts for relevant lines of text, both as a running total and next to each individual line. The core architecture is built around a block-based concept, where different parts of the text can have different types and behaviors.

## 2. Core Concept: Block-Based Editing

All text within the editor is managed by `BlockBasedTextStorage`. This custom text storage class applies attributes to ranges of text, primarily a `blockType` attribute. This `blockType` (defined in `Models/BlockType.swift`) determines how a section of text is treated (e.g., as a standard text paragraph eligible for calorie calculation, or potentially other types like image placeholders in the future).

Currently, user-typed text is automatically attributed as `.textBlock` by `BlockBasedTextStorage` during editing.

## 3. Key Components and Data Flow

The editor functionality is distributed across several files:

**SwiftUI Layer (User Interface & State Management):**

*   **`ContentView.swift`**:
    *   The main SwiftUI view that hosts the editor.
    *   Manages high-level state:
        *   `@State text`: The raw text content of the editor.
        *   `@State totalCalories`: The sum of calories from all paragraphs.
        *   `@State isEditing`: Tracks if the editor is focused.
    *   Passes bindings and callbacks to `CalorieTextEditor`.
    *   Provides the `calculateCalories` closure, which calls `CalorieCalculationService.shared.calculateCaloriesFor`.

**SwiftUI to UIKit Bridge:**

*   **`Editor/CalorieTextEditor.swift`**:
    *   A `UIViewRepresentable` struct.
    *   Acts as the bridge between the SwiftUI world (`ContentView`) and the UIKit-based `CalorieTextView`.
    *   **Responsibilities:**
        *   Creates and configures an instance of `CalorieTextView`.
        *   Sets up a `Coordinator` to handle `UITextViewDelegate` methods.
        *   Synchronizes the `text` binding between SwiftUI and `CalorieTextView`.
        *   Passes the `calculateCalories` function from `ContentView` to `CalorieTextView`'s `onNeedCalorieCalculation` callback.
        *   Updates `ContentView`'s `totalCalories` via the `onTotalCaloriesChanged` callback from `CalorieTextView`.
        *   Handles UI updates when bound state variables change (e.g., refreshing `CalorieTextView.text`).

**UIKit Layer (Core Text Editing & Display):**

*   **`Editor/CalorieTextView.swift`**:
    *   A custom `UITextView` subclass. This is where the main text editing and per-line calorie display logic resides.
    *   **Responsibilities:**
        *   Uses `BlockBasedTextStorage` as its text storage engine.
        *   **Paragraph Management**:
            *   When text changes (`textDidChange`):
                *   It calls `updateParagraphs()` to parse the `textStorage` into an array of `ParagraphInfo` objects.
                *   Each `ParagraphInfo` stores its range, text, `blockType` (read from `BlockBasedTextStorage`), and calculated `calories`.
        *   **Calorie Calculation Triggering**:
            *   For each valid `.textBlock` identified in `updateParagraphs()`, it calls `self.calculateCalories(for:text:)`.
            *   This, in turn, invokes the `onNeedCalorieCalculation` callback (wired to `CalorieCalculationService`).
        *   **Per-Line Calorie Display**:
            *   After calorie calculation, it calls `scheduleCalorieDisplayUpdate()`, which debounces and then calls `updateCalorieDisplay()`.
            *   `updateCalorieDisplay()` delegates to `TextEditorLayoutManager` to draw/update `UILabel`s next to paragraphs that have calculated calories.
        *   **Callbacks to `CalorieTextEditor`**:
            *   `onTextChanged`: Notifies when the text content has changed.
            *   `onNeedCalorieCalculation`: Signals that a specific string needs its calories calculated.
            *   `onTotalCaloriesChanged`: Notifies when the sum of all paragraph calories changes.
        *   Manages the currently active paragraph for potential future UI hints.

*   **`Editor/BlockBasedTextStorage.swift`**:
    *   A custom `NSTextStorage` subclass. It's the heart of the block-based system.
    *   **Responsibilities:**
        *   Stores the actual characters and their attributes.
        *   Overrides `replaceCharacters(in:with:)` and `setAttributes(_:range:)`.
        *   Its `processEditing()` method (called after edits) is crucial: it iterates over the edited range and applies default attributes, including `.blockType = .textBlock`, to ensure user-typed text is correctly identified for calorie processing.
        *   Allows different `blockType` attributes to be set on different ranges of text, enabling distinct behaviors.

*   **`Editor/TextEditorLayoutManager.swift`**:
    *   A helper class used by `CalorieTextView`.
    *   **Responsibilities:**
        *   `layoutCalorieLabels()`:
            *   Takes the array of `ParagraphInfo` objects and the `CalorieTextView`.
            *   For each `ParagraphInfo` that has a non-nil `calories` value (and is not empty), it creates, configures, and positions a `UILabel` to display the calorie count.
            *   The label is positioned to the right of the corresponding paragraph in the `CalorieTextView`.

**Data Models:**

*   **`Models/ParagraphInfo.swift`**:
    *   A `struct` representing a single paragraph within the `CalorieTextView`.
    *   **Properties:**
        *   `id`: A unique identifier.
        *   `range`: The `NSRange` of the paragraph in the `textStorage`.
        *   `text`: The string content of the paragraph.
        *   `calories`: An optional `Int` for the calculated calories.
        *   `blockType`: A `BlockType` enum value indicating the paragraph's nature (e.g., `.textBlock`).
        *   `isEmpty`: A computed property to check if the paragraph text is empty after trimming.
        *   `isLastParagraph`: (Currently less used in the calorie flow but available).

*   **`Models/BlockType.swift`**:
    *   An `enum` defining the different types of blocks the editor can handle.
    *   **Cases:**
        *   `.textBlock`: Standard text, eligible for calorie calculation.
        *   `.imagePlaceholder`: Reserved for future image attachment functionality.
        *   `.calorieMarker`: (Legacy from previous button-based approach) Currently not actively used by the automatic calorie display logic but remains defined. Could be repurposed.

**Services (Assumed):**

*   **`CalorieCalculationService.swift`** (Path and exact implementation not detailed here, but its interface is used):
    *   An external (likely asynchronous) service.
    *   `shared.calculateCaloriesFor(text: String, completion: @escaping (Int) -> Void)`: Takes a string and returns its calculated calorie value via a completion handler.

## 4. Automatic Calorie Calculation and Display Workflow

1.  **User Input**: User types text into the `CalorieTextView`.
2.  **Text Storage Processing**: `BlockBasedTextStorage.processEditing()` (or other attribute-setting methods) ensures the typed text is marked with `blockType = .textBlock`.
3.  **Notification**: `UITextView.textDidChangeNotification` is posted.
4.  **`CalorieTextView.textDidChange()` is called**:
    *   Invokes `onTextChanged` (callback to `CalorieTextEditor`, updating `ContentView.text`).
    *   Clears existing `paragraphs` and `calorieLabels`.
    *   Calls `updateParagraphs()`.
5.  **`CalorieTextView.updateParagraphs()` executes**:
    *   Iterates through the text in `textStorage` paragraph by paragraph.
    *   For each paragraph:
        *   Reads its `blockType` attribute from `textStorage`.
        *   If `blockType` is `.textBlock` and the paragraph's trimmed text is not empty:
            *   A new `ParagraphInfo` object is created (text, range, blockType).
            *   `self.calculateCalories(for: newIndex, text: trimmedTextForCalculation)` is called.
6.  **`CalorieTextView.calculateCalories(for:text:)` executes**:
    *   Calls the `onNeedCalorieCalculation` closure (which is `CalorieCalculationService.shared.calculateCaloriesFor(...)` provided by `ContentView`).
    *   **Asynchronously (in completion handler of `onNeedCalorieCalculation`)**:
        *   The calculated `calories` are received.
        *   The `calories` property of the corresponding `ParagraphInfo` object in the `paragraphs` array is updated.
        *   `self.scheduleCalorieDisplayUpdate()` is called.
7.  **`CalorieTextView.scheduleCalorieDisplayUpdate()` executes**:
    *   Debounces the call to prevent rapid UI updates.
    *   After the delay, it calls:
        *   `updateTotalCalories()`: Sums up all `calories` from the `paragraphs` array and updates `self.totalCalories` (which triggers the `onTotalCaloriesChanged` callback to `CalorieTextEditor`, updating `ContentView.totalCalories`).
        *   `updateCalorieDisplay()`.
8.  **`CalorieTextView.updateCalorieDisplay()` executes**:
    *   Calls `TextEditorLayoutManager.layoutCalorieLabels(...)`, passing the current `calorieLabels`, the `paragraphs` array, the `textView` instance, and the `activeParagraphIndex`.
9.  **`TextEditorLayoutManager.layoutCalorieLabels()` executes**:
    *   Removes all old calorie labels from `CalorieTextView`.
    *   Iterates through the `ParagraphInfo` array.
    *   For each `ParagraphInfo` where `calories` is not `nil` and `isEmpty` is `false`:
        *   Creates a new `UILabel`.
        *   Sets its text (e.g., "120 kcal").
        *   Calculates its frame to position it to the right of the paragraph.
        *   Adds the `UILabel` as a subview to `CalorieTextView`.
        *   Collects all new labels.
    *   Returns the array of new labels (which `CalorieTextView` stores in `self.calorieLabels`).

This workflow ensures that as the user types, relevant lines are automatically processed for calorie calculation, and the UI updates to show both the total and per-line calorie counts. 