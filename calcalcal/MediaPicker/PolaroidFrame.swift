import SwiftUI

/// Reusable polaroid card used by both the camera capture state and the
/// captured-photo review state. Owns the card's frame, shadow, responsive
/// sizing, and the square photo slot. Callers plug in two pieces of content:
///
/// - `photo`: whatever fills the square photo area (live camera preview,
///   captured `UIImage`, placeholder, …). It will be clipped to the preview
///   square automatically.
/// - `actions`: the row that sits below the photo (snap button, Retake /
///   Use Photo buttons, …).
///
/// Both slots receive the computed *frame width* so they can size themselves
/// relative to the card (e.g. the snap button scales with the polaroid).
///
/// Centralizing the visual treatment here guarantees the capture and review
/// states can never drift apart — tweaking a shadow or corner radius updates
/// both in lockstep.
struct PolaroidFrame<Photo: View, Actions: View>: View {

    // MARK: - Slots

    @ViewBuilder let photo: (_ frameWidth: CGFloat) -> Photo
    @ViewBuilder let actions: (_ frameWidth: CGFloat) -> Actions

    // MARK: - Layout Constraints
    //
    // The polaroid adapts to whatever width/height it's given, but stays within
    // a sensible range so it still *feels* like a polaroid across device sizes.
    //
    // Ratios are preserved from the original designer-picked values:
    //   - Frame:   320 × 400        → 4:5 portrait card
    //   - Preview: 290 × 290 square → border = (320-290)/2 = 15pt on each side

    /// Smallest frame width we'll ever render (keeps controls usable on iPhone SE).
    private let minFrameWidth: CGFloat = 280
    /// Largest frame width (stops the polaroid from ballooning on large devices).
    private let maxFrameWidth: CGFloat = 400
    /// Frame height / frame width. 5/4 = classic polaroid "tall card" shape.
    private let frameHeightRatio: CGFloat = 5.0 / 4.0
    /// Preview width / frame width. Preserves the designer's 15pt side border.
    private let previewRatio: CGFloat = 290.0 / 320.0
    /// Safe margins so the polaroid never kisses the screen edges.
    private let horizontalMargin: CGFloat = DSSpacing.md
    private let verticalMargin: CGFloat = DSSpacing.md

    /// Computed sizes for the current available space.
    struct Layout {
        let frameWidth: CGFloat
        let frameHeight: CGFloat
        let previewSize: CGFloat
        let cornerRadius: CGFloat = DSCornerRadius.lg
        let previewCornerRadius: CGFloat = DSCornerRadius.sm
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(for: geo.size)

            ZStack {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(DSColors.surface)
                    .shadow(color: DSColors.shadowHeavy, radius: 20, x: 0, y: 16)
                    .frame(width: layout.frameWidth, height: layout.frameHeight)

                VStack(spacing: DSSpacing.md) {
                    photo(layout.frameWidth)
                        .frame(width: layout.previewSize, height: layout.previewSize)
                        .clipShape(RoundedRectangle(cornerRadius: layout.previewCornerRadius))

                    actions(layout.frameWidth)
                }
                .frame(width: layout.frameWidth)
            }
            .frame(width: layout.frameWidth, height: layout.frameHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity) // center inside GeometryReader
        }
    }

    // MARK: - Layout computation

    /// Picks the largest polaroid size that (a) fits the offered space minus margins,
    /// (b) preserves the 4:5 frame ratio, and (c) respects min/max caps.
    private func computeLayout(for size: CGSize) -> Layout {
        let widthBudget = max(0, size.width - horizontalMargin * 2)
        let heightBudget = max(0, size.height - verticalMargin * 2)

        // Start by fitting the width, then cap at max.
        var frameWidth = min(widthBudget, maxFrameWidth)
        var frameHeight = frameWidth * frameHeightRatio

        // If that would overflow vertically, scale down to fit the height instead.
        if frameHeight > heightBudget && heightBudget > 0 {
            frameHeight = heightBudget
            frameWidth = frameHeight / frameHeightRatio
        }

        // Enforce a floor. In very tight layouts this may slightly overflow —
        // that's a deliberate trade to keep tap targets usable.
        frameWidth = max(frameWidth, minFrameWidth)
        frameHeight = frameWidth * frameHeightRatio

        let previewSize = frameWidth * previewRatio

        return Layout(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            previewSize: previewSize
        )
    }
}

// MARK: - Shared Metrics

/// Sizing helpers for content that lives inside a `PolaroidFrame`.
///
/// Consumed by both the capture state (`CameraPolaroidView`) and the review
/// state (`PhotoPreviewView`) so their action rows stay visually in lockstep.
/// If we ever want buttons to be taller/shorter, we change it here and both
/// states update together.
enum PolaroidMetrics {

    // Designer's original snap-button numbers. The button width is ~19% of
    // the polaroid's frame width, clamped to a comfortable tap-target range.
    private static let snapWidthRatio: CGFloat = 60.0 / 320.0
    private static let minSnapWidth: CGFloat = 130
    private static let maxSnapWidth: CGFloat = 160
    /// Action buttons are half as tall as the snap pill is wide (2:1 aspect).
    private static let actionHeightRatio: CGFloat = 0.5

    /// Width of the pill-shaped snap button at the given polaroid frame width.
    ///
    /// At the current min/max polaroid sizes (280–400pt) the ratio `60/320`
    /// always falls below 130pt, so this effectively returns **130pt** in
    /// practice — the tap-target floor dominates.
    static func snapButtonWidth(frameWidth: CGFloat) -> CGFloat {
        min(max(frameWidth * snapWidthRatio, minSnapWidth), maxSnapWidth)
    }

    /// Height for anything that sits in the action row (snap button, Retake
    /// and Use Photo buttons, any future action). Scales with the polaroid
    /// so controls keep the same vertical weight across device sizes.
    ///
    /// Derived from the snap pill so capture and review states match:
    ///   height = snapWidth × 0.5 → **65pt** at today's min/max polaroid sizes.
    static func actionButtonHeight(frameWidth: CGFloat) -> CGFloat {
        snapButtonWidth(frameWidth: frameWidth) * actionHeightRatio
    }
}
