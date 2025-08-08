# Food Log User Interface Structure

The food log interface is designed as a rich text editor with mixed content types, allowing users to create detailed diary entries with text, images, and AI-analyzed nutritional data. Here's how the interface works:

#### Entry Structure
Each daily diary entry contains multiple **blocks** that can be:
- **Text blocks**: Natural language food descriptions
- **Image blocks**: Food photos uploaded by the user
- **Image+Text blocks**: Photos with accompanying text descriptions
- **Spacer blocks**: Visual separation between content

#### Block Types and UI Behavior

**Text Blocks:**
- Rich text editor with natural language input
- Real-time AI analysis as user types
- Shows nutritional breakdown (calories, protein, fat, carbs) below text
- Editable nutritional values (user can override AI estimates)


**Image+Text Blocks:**
- Combined photo and text description
- Enhanced AI analysis using both visual and textual data
- More accurate nutritional estimates
- Text can provide context for image analysis

**Spacer Blocks:**
- Visual separation between meal sections
- No nutritional data
- Helps organize diary entries by meal time

#### UI Layout Example
```
┌─────────────────────────────────────┐
│ 📅 December 15, 2024                │
│                                     │
│ [Text Block]                        │
│ "Had a delicious chicken sandwich   │
│  with avocado and whole wheat bread"│
│                                     │
│ 🍽️ 450 kcal | 🥩 35g protein |     │
│ 🥑 22g fat | 🍞 28g carbs          │
│                                     │
│ 🍽️ 320 kcal | 🥩 25g protein |     │
│ 🥑 18g fat | 🍞 20g carbs          │
│                                     │
│                                     │
│ [Image+Text Block]                  │
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │        [Food Photo]             │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│ "Greek yogurt with berries and     │
│  honey for dessert"                 │
│                                     │
│ 🍽️ 180 kcal | 🥩 15g protein |     │
│ 🥑 8g fat | 🍞 22g carbs           │
│                                     │
│ 📊 Daily Total: 950 kcal            │
│ 🎯 Goal: 2000 kcal (47% complete)   │
└─────────────────────────────────────┘
```

#### Real-time Features
- **Live AI Analysis**: Nutritional data appears as user types
- **Auto-save**: Changes saved automatically to prevent data loss
- **Offline Support**: Works without internet, syncs when connected
- **Real-time Sync**: Changes appear instantly across devices
- **Conflict Resolution**: Handles simultaneous edits gracefully

#### Block Management
- **Add/Remove**: Insert new blocks at any position
- **Copy/Paste**: Duplicate blocks between entries
- **Undo/Redo**: Full editing history support

#### Nutritional Display
- **Individual Block Nutrition**: Each block shows its own nutritional breakdown
- **Running Totals**: Real-time calculation of daily totals
- **Goal Progress**: Visual indicators for daily goal completion
- **Macro Ratios**: Protein/fat/carb percentages

This flexible block-based structure allows users to create rich, detailed food logs while maintaining the simplicity of natural language input and the accuracy of AI-powered nutritional analysis.
