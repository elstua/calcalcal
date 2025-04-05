# CLAUDE.md for calcalcal

## Build and Test Commands
- Build: Open in Xcode and use ⌘+B or Product > Build
- Run: Use ⌘+R or Product > Run
- Test All: ⌘+U or Product > Test
- Single Test: Select test in navigator, right-click and choose "Run Test"
- Clean: ⌘+Shift+K or Product > Clean Build Folder

## Code Style Guidelines

### Structure
- Models/ for data structures
- Services/ for business logic
- Editor/ for text editing components
- Views/Components/ for reusable UI elements

### Formatting
- 4-space indentation
- Opening braces on same line
- Blank line after imports
- Use MARK: comments for section organization

### Naming & Types
- camelCase for variables, properties, methods
- PascalCase for types (classes, structs, enums)
- Descriptive function names (e.g., calculateCaloriesFor)
- Strong typing with explicit optionals

### Error Handling
- Use optional chaining for potential nil values
- guard let/if let for safe unwrapping
- Provide default values for error cases

### Patterns
- Singleton pattern for services (shared instance)
- Delegate pattern for UIKit components
- Callback closures for async operations