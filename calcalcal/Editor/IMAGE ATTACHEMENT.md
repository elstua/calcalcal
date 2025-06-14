# Image attachement in calcalcal 
In this document I described how should work image attachement in calcal's editor.
We currently have implementation of imageblock in editor, described in architecture.md, but we need to implement a feature for adding this images to the textview.

## Basic flow
1. User press some + button
2. Calcalcal open page with gallery and photo
3.1. User makes photo
3.2 User select photo from gallery
4. in backend we send image to the LLM to generate an description of food on picture and answer of how many calories in it
5. in UI image flies to its coordinate on the textfield (place where we add new imageblock paragraph)
6. we show some loader placeholder in the text area while we get text from LLM
7. once we receive it, text start to stream into it's place

Now let's describe the main parts of image page:

### Image page
Main idea is to make it's unified place to cut user's clicks to selection for the right option. We open on one screen camera view in the center of the screen and show gallery of last images on the bottom
User can scroll to see all their images. We should implement this place and all components it has in it. I believe it can be simple SwiftUI screen without any complex additional logic in it.
- It opens from + button
- It can be closed by swipe the view down or by tap on the cross icon in the top right corner
- background for this page is opaque, dark and with some opacity to see content under it


#### Image component
Imagine it's like polaroid photo. We have rectangular white block with 2:3 proportions (can change) and relative border radius. In the top of this block with some margin is a square block with image itself. Image is cropped by this square and centered.

- this is the core element and can be a small (in textview and gallery) and on the large screen (when press on view photo)
- Optionally in large version should be controls for interaction (... button that shows some options like "delete" or "retake")
- when image/photo is selected we disable bg of image page and move it to its coordinate on textview. Additionally it can be two different blocks in different view: one on the image and one on the textview. That shares the same coordinates on the start. This transition should be flawless and fluid

### gallery view
Is basically a grid of the image component. Should be like 3 image per row, and interaction with it depends of the context:
- in image page it should select image and add it with animation to the textview
- longpress should open image on the whole screen
- on the first opening its ask permission to gallery in system
- if user disable access to gallery, we show blurred placeholders and text "enable access to gallery in settings" on top of it 

### camera block
It's enlarge image component (white 2:3 rectangle with square content), but instead of image there should be camera. On the middle part we have controls: circle button that makes photo in the center, flashlight in the left side.
- on the first opening page it should ask for camera access, and if it disabled — we hide camera and write "enable access to the camera in calcalcal's settings"
- After making photo we disable bg of image page and move it to its coordinate on textview. Additionally it can be two different blocks in different view: one on the image and one on the textview. That shares the same coordinates on the start. This transition should be flawless and fluid

## Process
### First steps for MLP:
1. implement component for images and logic on opening it
2. implement component for gallery
    with state of disabled access
3. Implement image page and opening it from the textview
3. Understand how to add it to the textview fluidly and with right animation
### Second steps:
4. implement component of camera
    state of disabled access
    share the same logic for adding it into the textview
5. add it to the image page
### third step
6. Add animations and define styles for opening/close


## Additional requirements
- on opening it should be animate: all blocks goes from the down and small blur to their original position
- Let's create all this components and logic inside Image Place folder. If some logic relates to the editor, we put it to the editor

## implementation description

TBD
