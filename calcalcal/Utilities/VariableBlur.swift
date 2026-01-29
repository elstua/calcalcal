// VariableBlur – progressive/variable blur (gradual blur by position).
// Adapted from https://github.com/nikstar/VariableBlur
// Used for header progressive blur per https://designcode.io/swiftui-handbook-progressive-blur

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import QuartzCore

enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

struct VariableBlurView: UIViewRepresentable {
    var maxBlurRadius: CGFloat = 20
    var direction: VariableBlurDirection = .blurredTopClearBottom
    var startOffset: CGFloat = 0

    init(maxBlurRadius: CGFloat = 20, direction: VariableBlurDirection = .blurredTopClearBottom, startOffset: CGFloat = 0) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }

    func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    func updateUIView(_ uiView: VariableBlurUIView, context: Context) {
        uiView.updateBlur(maxBlurRadius: maxBlurRadius)
    }
}

/// Variable blur: blur strength follows a gradient (e.g. strong at top, clear at bottom).
/// Credit: https://github.com/jtrivedi/VariableBlurView via https://github.com/nikstar/VariableBlur
final class VariableBlurUIView: UIVisualEffectView {

    private var variableBlurFilter: NSObject?
    private var backdropLayer: CALayer?
    private let direction: VariableBlurDirection
    private let startOffset: CGFloat

    init(maxBlurRadius: CGFloat = 20, direction: VariableBlurDirection = .blurredTopClearBottom, startOffset: CGFloat = 0) {
        self.direction = direction
        self.startOffset = startOffset
        super.init(effect: UIBlurEffect(style: .regular))

        let clsName = String("retliFAC".reversed())
        guard let Cls = NSClassFromString(clsName) as? NSObject.Type else {
            return
        }
        let selName = String(":epyThtiWretlif".reversed())
        guard let variableBlur = Cls.perform(NSSelectorFromString(selName), with: "variableBlur")?.takeUnretainedValue() as? NSObject else {
            return
        }
        variableBlurFilter = variableBlur

        let gradientImage = makeGradientImage(startOffset: startOffset, direction: direction)
        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        if let layer = subviews.first?.layer {
            backdropLayer = layer
            layer.filters = [variableBlur]
        }
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    func updateBlur(maxBlurRadius: CGFloat) {
        variableBlurFilter?.setValue(maxBlurRadius, forKey: "inputRadius")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}

    private func makeGradientImage(width: CGFloat = 100, height: CGFloat = 100, startOffset: CGFloat, direction: VariableBlurDirection) -> CGImage {
        let ciGradientFilter = CIFilter.linearGradient()
        ciGradientFilter.color0 = CIColor.black
        ciGradientFilter.color1 = CIColor.clear
        ciGradientFilter.point0 = CGPoint(x: 0, y: height)
        ciGradientFilter.point1 = CGPoint(x: 0, y: startOffset * height)
        if case .blurredBottomClearTop = direction {
            ciGradientFilter.point0.y = 0
            ciGradientFilter.point1.y = height - ciGradientFilter.point1.y
        }
        guard let output = ciGradientFilter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return makeFallbackGradientImage(width: width, height: height)
        }
        return cgImage
    }

    private func makeFallbackGradientImage(width: CGFloat = 100, height: CGFloat = 100) -> CGImage {
        let filter = CIFilter.linearGradient()
        filter.color0 = CIColor.black
        filter.color1 = CIColor.clear
        filter.point0 = CGPoint(x: 0, y: height)
        filter.point1 = CGPoint(x: 0, y: 0)
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            fatalError("VariableBlur: failed to create gradient image")
        }
        return cgImage
    }
}
