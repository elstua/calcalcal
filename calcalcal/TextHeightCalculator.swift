import SwiftUI
import UIKit

struct TextHeightCalculator {
    static func calculateHeight(
        for text: String,
        width: CGFloat,
        font: UIFont = .systemFont(ofSize: 17) // Default iOS TextField font size
    ) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
}