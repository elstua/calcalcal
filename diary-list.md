# Overview of Diary List
Even that main function of Calcalcal is editor (check Editor/ARCHITECTURE.MD), main screen that user will see most of the time is a diary list. 
Basically it's a list of all user input logs, splitted by days. every list item is one unifiedtextview with their own id, calorie summary and text, entered by user.

Every "today" is an open unifiedtextview block with white background and take some big height of the screen (like 550pt).
All other days are smaller views, with some summary text, calorie and date.

Tap on any of this blocks open unifiedtextview page (let's call it editor page) with focus state and keyboard.

# Data Structure

Based on the existing Editor implementation, each diary entry will use the following structure:

## DiaryEntry Model
```swift
struct DiaryEntry {
    let id: UUID
    let date: Date
    var blocks: [Block] // From Editor/BlockModel.swift
    var totalCalories: Int? // Calculated from all blocks with calorieData
    var lastModified: Date
    var aiGeneratedSummary: String? // For display in small blocks
}
```

## Block Structure (from Editor)
```swift
struct Block {
    var type: BlockType
    var calorieData: String? // e.g., "120 kcal"
}

enum BlockType {
    case text(String)
    case image(Data, UUID)
    case imageText(Data, UUID, String)
    case spacer
}
```

## Data Management
- **Storage**: Each day has a single `DiaryEntry` with an array of `Block` objects
- **Auto-save**: Changes to the "today" block are automatically saved as user types
- **Transition**: When a new day starts, the previous "today" entry becomes a "small" block automatically
- **Empty States**: Days with no entries show empty state with placeholder text
- **Mock Data**: For initial implementation, all calorie calculations and AI summaries will be mocked

# Components
1. **"today" block**. Large state of UnifiedEditorDemoView.swift that shows initial content inside.
    - has date on top (header) in format like "NN Month-name" (12 September)
    - has footer with addbutton that open gallery on the left and calorie summary on the right
    - contentview is our implemented editor in last changed state
    - it's white bg, round corners
    - auto-saves as user types
    - height: ~550pt
1.5 **entry footer block** should be a different component, because we will reuse it in the opened editor and it will have a couple of states based on interaction (scrolled/normal)
    - On the left we show addbutton that opens gallery.
    - on the right we show calorie summary (can be mocked for now)
2. **"small" block**. Small version of diary entry.
    - has number of date, "NN"
    - two lines of AI-generated summary text (mocked for now)
    - calorie summary (calculated from all blocks with calorieData)
    - shows empty state if no entries for that day
3. **"opened" editor**. When user pressed on any of components, we show opened editor with focus on it. Editor opened as sheet, can be closed by swiping down.
    - structure is the same as "today block". They could be one component with different states, for example
    - uses the same UnifiedTextEditor from Editor/
4. **Diary list** itself
    - have one today block and 30 small blocks (going back 30 days from today)

For now we can implement everything in standard UI components in SwiftUI

# Architectural stuff
- We always should count from current day down to the last month (ie 30 days).
    - in future if user will have more than 30 days we will figure this out and show more. But from the start we should show 30
- in the future implementation I want to make open of editor more smooth, through matchedgeometry interaction

# Implementation Notes
- **Gallery Integration**: Already implemented in `GalleryView.swift` and `UnifiedEditorDemoView.swift` - no need to reimplement
- **Calorie Calculation**: Will be handled in backend/other views - not part of diary list implementation
- **Image Handling**: Already implemented in Editor - diary list just displays the results
- **Mock Data**: For initial implementation, use mock data for:
  - AI-generated summaries (use first 2 lines of text or placeholder)
  - Calorie calculations (random numbers for testing)
  - Empty states (placeholder text)

# Plan of creation
First of all we should build a simple UI solution and match it with backend later
1. Build all main components and match main interactions between them
2. implement them in unified user flow
future steps after implementing backend
3. match days logs with user logs
4. implement real calorie calculation and AI summaries
5. add matchedgeometry animations for smooth transitions
