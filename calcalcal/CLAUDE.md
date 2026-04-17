# CalCalCal iOS App — Development Guide

SwiftUI + UIKit hybrid, MVVM architecture, targeting iOS.

## Directory Structure

```
AppDelegate.swift              # App lifecycle, Google Sign-In setup
Views/                         # Top-level screens and shared views
  AppEntry.swift               # Root view — auth gating, tab routing
  ContentView.swift            # Main content wrapper
  MainTabView.swift            # Tab bar (diary, profile)
  AuthChoiceView.swift         # Auth method selection
  LoginView.swift              # Login screen
  DiaryPagerView.swift         # Horizontal day pager
  DayStripView.swift           # Horizontal date strip navigation
  EditorOverlay.swift          # Full-screen editor overlay (entry editing)
  EditorFooterView.swift       # Footer bar in editor (camera, gallery, etc.)
  CalorieBarrelView.swift      # Animated calorie counter (barrel roll digits)
  GalleryThumbnailButton.swift # Thumbnail button for gallery access
  ImagePicker.swift            # UIImagePickerController wrapper
  MatchedEditorSource.swift    # matchedGeometryEffect source for editor transitions
  NutritionPopupView.swift     # Nutrition details popup
DiaryList/                     # Diary list tab
  DiaryTabView.swift           # Main diary tab container
  DiaryTabViewModel.swift      # ViewModel: entry fetching, date management
  DiaryListView.swift          # Scrollable list of entries for a day
  EntryCard.swift              # Single entry card (text preview + calories)
  EntrySummaryCard.swift       # Collapsed entry summary
  AllDaysOverlay.swift         # Calendar/all-days view overlay
  DayTimeline.swift            # Timeline visualization
  CollapsedEmptyRunView.swift  # Placeholder for empty date ranges
  Streak*                      # Streak UI: button, popup, sheet, stats, droplet shape
EditorV2/                      # TextKit 2 block editor (core complexity)
  BlockModels.swift            # BlockDocument, BlockID, Block, BlockKind
  BlockDocumentController.swift # Observes NSTextStorage → rebuilds BlockDocument
  BlockEditorTextView.swift    # UITextView subclass — the actual editor
  BlockEditorRepresentable.swift # UIViewRepresentable bridge to SwiftUI
  BlockEditorBridge.swift      # Coordinator: bindings + callbacks between UIKit ↔ SwiftUI
  BlockTextAttributes.swift    # NSAttributedString styling per block kind
  BlockTextLayoutManager.swift # NSTextLayoutManagerDelegate — custom layout
  ParagraphBlockLayoutFragment.swift # Custom NSTextLayoutFragment for paragraphs
  CalorieBlockView.swift       # SwiftUI calorie label overlay per block
  CalorieOverlayMetrics.swift  # Positioning math for calorie overlays
  CalorieContextMenuView.swift # Context menu for calorie blocks
  DayOverviewContextMenuView.swift # Context menu for day overview
  PlainAttachmentEditor.swift  # Image attachment handling in editor
ImagePage/                     # Image viewing and gallery
  GalleryView.swift            # Full gallery view
  GalleryDisplayConfig.swift   # Gallery layout configuration
  ImageComponent.swift         # Reusable image display component
  ImageCompression.swift       # Image compression utilities
MediaPicker/                   # Camera and photo picker
  UnifiedMediaPickerView.swift # Combined camera + gallery picker
  CameraManager.swift          # AVCaptureSession management
  CameraPreviewView.swift      # Live camera preview
  CameraPolaroidView.swift     # Polaroid-style camera UI
  PhotoPreviewView.swift       # Photo review before attachment
  PickerGalleryView.swift      # Photo library grid picker
Models/                        # Data models, API, and state
  AppState.swift               # Global observable state (auth, onboarding, streaks)
  AuthManager.swift            # Apple/Google/temp account auth flows
  Configuration.swift          # API URL config from Info.plist/xcconfig
  DiaryAPI.swift               # All backend API calls
  APIClient.swift              # Low-level HTTP client with auth
  ImageAPI.swift               # Image upload/download API
  DiaryEntry.swift             # DiaryEntry model
  BlockModel.swift             # Block data model (text + nutrition)
  AnalyzedBlock.swift          # AI-analyzed block result
  BlocksCache.swift            # Local cache for blocks
  EntryIdentityCoordinator.swift # Coordinates entry identity across views
  StreaksModels.swift           # Streak data models
  User.swift                   # User model
  Session.swift                # Session model
  KeychainManager.swift        # Keychain token storage
  HealthKitManager.swift       # HealthKit integration
  HealthKitDebugHelper.swift   # HealthKit debug utilities
  ImageCache.swift             # Image caching
Onboarding/                    # Onboarding flow
  OnboardingContainerView.swift # Step container with navigation
  OnboardingCoordinator.swift  # Flow state machine
  OnboardingData.swift         # Collected onboarding data
  OnboardingStep.swift         # Step protocol
  OnboardingStepType.swift     # Step enum
  Steps/                       # Individual step views (Welcome, PersonalInfo, Height, Weight, ActivityLevel, HealthKit, AboutApp, CreateAccount, Ready)
Profile/                       # User profile and settings
  ProfileView.swift            # Profile screen
  SettingsView.swift           # Settings screen
  DeleteAccountConfirmationView.swift
Services/
  EditorAutosaveService.swift  # Autosave timer for editor content
DesignSystem/                  # Design tokens and components
  Foundation/                  # DSColors, DSSpacing, DSTypography, DSUIKitBridge
  Components/                  # DSButton, DSCard
  Configuration/               # DSConfiguration, DSEnvironment
Extensions/
  NotificationNames.swift      # Custom Notification.Name constants
Utilities/
  VariableBlur.swift           # Variable blur effect
  DataFlowLogger.swift         # Debug logging for data flow
  BindingExtensions.swift      # SwiftUI Binding helpers
ViewModifiers/
  ConditionalMatchedGeometry.swift
```

## EditorV2 — Critical Constraints

The TextKit 2 block editor is the most complex part of the app. These are hard-won rules:

1. **Do NOT subclass `NSTextContentStorage`** — causes `NSRangeException` crashes. Use the default provided by `UITextView`.
2. **Do NOT use `NSTextAttachment` for images** — causes caret to grow to attachment height. Instead, use invisible marker characters (`\u{FFFC}`) with `UIHostingController` overlays.
3. **Do NOT use `renderingAttributesValidator` for paragraph spacing** — causes caret/selection mismatch. Bake spacing into `NSAttributedString` via `typingAttributes`.
4. **Clamp all ranges** before any storage access.
5. **Never mutate attributes inside TextKit callbacks** — only observe and rebuild the model.

Object graph: `BlockEditorTextView` → `BlockDocumentController` (observes NSTextStorage, rebuilds `BlockDocument`) → `BlockTextLayoutManager` (custom layout fragments per block kind).

## Callback Threading Pattern

Image/media data flows through multiple layers, each with its own callback signature:

`GalleryView` → `PickerGalleryView` → `UnifiedMediaPickerView` → `EditorOverlay` → `EntryCard` → `BlockEditorRepresentable` → `BlockEditorTextView`

Threading new parameters requires updating all layers in this chain.

## Key Patterns

- **State**: `AppState` is the global `ObservableObject` — auth status, onboarding, streaks
- **Auth**: `AuthManager` handles Apple Sign-In, Google Sign-In, and temporary accounts
- **Networking**: All API calls go through `DiaryAPI` → `APIClient` with JWT Bearer tokens
- **Config**: `Configuration.swift` reads `API_URL` from Info.plist (set by xcconfig). Single-slash URLs in xcconfig are fixed at runtime.
- **Design system**: Always use `DSColors`, `DSSpacing`, `DSTypography`, `DSCard`, `DSButton` tokens for new UI
- **Notifications**: Custom names defined in `Extensions/NotificationNames.swift`
- **BlockID**: Public struct wrapping UUID, defined in `EditorV2/BlockModels.swift`
