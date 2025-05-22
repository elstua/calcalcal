Based on previous chat @Transforming Input Field Architecture for Block Injection  of changing model to "blocks" now I want to implement the flow of adding images. We already build logic in the chat @iOS Project: Image and Text Integration. Idea is to make image as a special symbol and place it into the block "image" that will continue to have previously build layout (image on left, pregenerated text on right). Currently all this logic is just commented in code

Let's start to turn it on and validate that everything works in the new structure with some big changes. Right now it's just a grey block just to figure out the layout

1. Image will have 30% width of text area, as we already developed
2. text will be on the right side, as we developed
3. text WILL NOT move under the image if there is more lines. In image block size of text area is always 70%, as a 30% used for image.
4. Pressing Enter will create a new block and move cursor under the image
5. image can't be deleted as a text, in this case we will transform image block into text block.
    - this will change approach to the image drastically. Probably it shouldn't be just a text, but, should be like a block that stays in the left of the text.
    -we should explore this approach to make it as simple as possible. Maybe just make image symbols non-deletable

## future updates
- images will be clickable. Tap on it will smoothly enlarge it and show additional controls like delete or close.
