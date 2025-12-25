# Camera + Gallery Unified Picker

This document defines the unified camera and gallery picker that replaces the standard iOS image picker. The goal is to reduce friction when adding food photos for calorie analysis.

## Overview

Instead of opening a standard `UIImagePickerController`, pressing the `+` button in `EntryFooterView` opens a custom full-screen overlay with:
- Live camera preview in a polaroid-style frame
- First 3 gallery images below
- Swipe gestures for navigation and dismissal

## User Journey

### Default State (Camera Mode)
```
┌─────────────────────────────────────┐
│                              [⚡]   │  ← Flash toggle (top right)
│                                     │
│    ┌─────────────────────────┐      │
│    │                         │      │
│    │    [LIVE CAMERA FEED]   │      │  ← Polaroid frame with camera
│    │                         │      │
│    │         ⚪              │      │  ← Snap button inside frame
│    └─────────────────────────┘      │
│                                     │
│  ┌────┐  ┌────┐  ┌────┐            │  ← First 3 gallery images
│  │img1│  │img2│  │img3│            │
│  └────┘  └────┘  └────┘            │
│                                     │
│         ↑ Swipe gallery up          │
└─────────────────────────────────────┘
```

### Gallery Expanded State
When user swipes the gallery section up:
```
┌─────────────────────────────────────┐
│  [X]                    [📷 Camera] │  ← Header with close + camera button
├─────────────────────────────────────┤
│  ┌────┐  ┌────┐  ┌────┐            │
│  │img1│  │img2│  │img3│            │
│  └────┘  └────┘  └────┘            │
│  ┌────┐  ┌────┐  ┌────┐            │
│  │img4│  │img5│  │img6│            │  ← Full scrollable gallery
│  └────┘  └────┘  └────┘            │
│  ...                                │
└─────────────────────────────────────┘
```

### Photo Preview State (After Snap)
After taking a photo, show the same polaroid view but with the captured image:
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│    ┌─────────────────────────┐      │
│    │                         │      │
│    │    [CAPTURED PHOTO]     │      │  ← Same polaroid frame
│    │                         │      │
│    │   [Retake]    [Use]     │      │  ← Action buttons inside frame
│    └─────────────────────────┘      │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

## Gestures & Navigation

| State | Gesture | Action |
|-------|---------|--------|
| Camera mode | Swipe down | Close picker |
| Camera mode | Swipe gallery up | Expand to full gallery |
| Gallery expanded | Swipe down (at top) | Collapse to camera mode |
| Gallery expanded | Swipe down (second) | Close picker |
| Gallery expanded | Tap camera button | Collapse to camera mode |
| Preview mode | Tap "Retake" | Return to camera mode |
| Preview mode | Tap "Use" | Insert image + close |
| Any state | Tap gallery image | Insert image + close |

## Component Architecture

```
UnifiedMediaPicker/
├── UnifiedMediaPickerView.swift      # Main container, state management
├── CameraPreviewView.swift           # AVFoundation camera preview
├── CameraPolaroidView.swift          # Polaroid frame with camera/image
├── GalleryStripView.swift            # Horizontal strip (3 images)
├── ExpandedGalleryView.swift         # Full scrollable gallery
└── PhotoPreviewView.swift            # Captured photo preview with actions
```

### State Machine

```swift
enum MediaPickerState {
    case camera           // Default: camera + 3 gallery images
    case galleryExpanded  // Full gallery, camera hidden
    case photoPreview(UIImage)  // After snap, showing captured photo
}
```

### Key Components

#### 1. UnifiedMediaPickerView (Main Container)
- Manages `MediaPickerState`
- Handles gesture recognition for swipe up/down
- Coordinates transitions between states
- Calls `onImageSelected(UIImage)` when user selects/uses photo

#### 2. CameraPreviewView
- Wraps `AVCaptureSession` with `AVCaptureVideoPreviewLayer`
- UIViewRepresentable for SwiftUI integration
- Handles camera setup, flash toggle
- Provides `capturePhoto()` method

#### 3. CameraPolaroidView
- Reuses polaroid styling from `ImageComponent`
- Contains either:
  - Live camera preview + snap button
  - Captured image + retake/use buttons
- White rounded rectangle frame
- Snap button: large white circle at bottom of frame

#### 4. GalleryStripView
- Shows first 3 images from photo library
- Reuses `ImageComponent` (small mode)
- Horizontal layout
- Tap to select

#### 5. ExpandedGalleryView
- Adapts existing `GalleryView` logic
- Full LazyVGrid with all photos
- Header with X button and camera button
- Scrollable

#### 6. PhotoPreviewView
- Shows captured photo in polaroid frame
- "Retake" button (left) - returns to camera
- "Use Photo" button (right) - confirms selection

## Implementation Details

### Camera Setup (AVFoundation)

```swift
class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isSessionRunning = false
    
    func configure() {
        // Request camera permission
        // Setup capture session with back camera
        // Add photo output
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }
}
```

### Gesture Handling

```swift
// In camera mode: DragGesture on entire view
// - downward drag > threshold = dismiss
// - upward drag on gallery area = expand gallery

// In gallery expanded mode:
// - Use ScrollView's built-in scrolling
// - When scrolled to top + pull down = collapse to camera
// - Requires custom scroll position detection
```

### Integration with Existing Code

**EntryFooterView.swift** - No changes needed (already calls `onAddImage`)

**EditorOverlay.swift** - Replace:
```swift
// OLD
.sheet(isPresented: $showImagePicker) {
    ImagePicker(image: $pickedImage)
    ...
}

// NEW
.fullScreenCover(isPresented: $showImagePicker) {
    UnifiedMediaPickerView(
        onImageSelected: { image in
            handleImageSelected(image)
            showImagePicker = false
        },
        onDismiss: {
            showImagePicker = false
        }
    )
}
```

**MainTabView.swift** - Same pattern for its image picker

### Permissions

Add to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos of your food for calorie tracking.</string>
```

Already exists:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Need to get the images for calorie tracking.</string>
```

### Reusable Components

**From ImageComponent.swift:**
- Polaroid frame styling (white rounded rectangle)
- Shadow and corner radius values
- Image display within frame

**From GalleryView.swift:**
- Photo library fetching logic (`PHPhotoLibrary`)
- Permission handling
- Image request with `PHCachingImageManager`

## Animations & Transitions

1. **Opening**: Slide up from bottom (standard fullScreenCover)
2. **Gallery expand**: 
   - Camera polaroid animates up and out (opacity fade + scale down)
   - Gallery grid animates up to fill space
   - Header fades in from top
3. **Gallery collapse**:
   - Reverse of expand animation
4. **Photo preview**:
   - Quick crossfade from camera to captured image

## Edge Cases

1. **Camera permission denied**: Show polaroid with "Enable Camera in Settings" message, gallery still works
2. **Photos permission denied**: Show empty gallery strip with "Enable Photos in Settings"
3. **No photos in library**: Show empty state in gallery
4. **Camera not available** (simulator): Show placeholder, gallery still works
5. **Low light**: Flash toggle becomes more prominent (optional: auto-suggest flash)

## File Changes Summary

### New Files
- `calcalcal/MediaPicker/UnifiedMediaPickerView.swift`
- `calcalcal/MediaPicker/CameraManager.swift`
- `calcalcal/MediaPicker/CameraPreviewView.swift`
- `calcalcal/MediaPicker/CameraPolaroidView.swift`
- `calcalcal/MediaPicker/GalleryStripView.swift`
- `calcalcal/MediaPicker/ExpandedGalleryView.swift`
- `calcalcal/MediaPicker/PhotoPreviewView.swift`

### Modified Files
- `Info.plist` - Add `NSCameraUsageDescription`
- `EditorOverlay.swift` - Replace `.sheet` with `.fullScreenCover` using new picker
- `MainTabView.swift` - Same change if it has its own image picker
- `Project.swift` or Xcode project - Add new files to target

### Potentially Reusable (Extract shared logic)
- `GalleryView.swift` - Extract photo fetching into shared utility
- `ImageComponent.swift` - Already reusable as-is

## Implementation Order

1. **Phase 1: Camera Foundation**
   - Add `NSCameraUsageDescription` to Info.plist
   - Create `CameraManager` class
   - Create `CameraPreviewView` (UIViewRepresentable)
   - Test camera capture works

2. **Phase 2: Polaroid Camera View**
   - Create `CameraPolaroidView` with live preview
   - Add snap button
   - Add flash toggle
   - Test photo capture

3. **Phase 3: Photo Preview**
   - Create `PhotoPreviewView`
   - Retake / Use Photo buttons
   - Test flow: snap → preview → use

4. **Phase 4: Gallery Strip**
   - Create `GalleryStripView` (3 images)
   - Extract photo fetching from `GalleryView`
   - Tap to select

5. **Phase 5: Expanded Gallery**
   - Create `ExpandedGalleryView`
   - Header with X and camera button
   - Scrollable grid

6. **Phase 6: Main Container**
   - Create `UnifiedMediaPickerView`
   - State management
   - Gesture handling for transitions

7. **Phase 7: Integration**
   - Replace `ImagePicker` usage in `EditorOverlay`
   - Replace in `MainTabView` if needed
   - Test full flow

8. **Phase 8: Polish**
   - Animations and transitions
   - Permission edge cases
   - Visual refinements

## Testing Checklist

- [ ] Camera permission request on first open
- [ ] Camera preview displays correctly
- [ ] Flash toggle works
- [ ] Snap captures photo
- [ ] Preview shows captured photo
- [ ] Retake returns to camera
- [ ] Use Photo inserts and analyzes
- [ ] Gallery images load
- [ ] Tap gallery image inserts and analyzes
- [ ] Swipe gallery up expands
- [ ] Swipe down collapses gallery
- [ ] Second swipe down dismisses
- [ ] Camera button in header works
- [ ] X button dismisses
- [ ] Permission denied states show correctly
- [ ] Works on device (not just simulator)
