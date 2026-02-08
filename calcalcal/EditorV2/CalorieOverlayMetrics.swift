import UIKit

enum CalorieOverlayMetrics {
    static let labelMinWidth: CGFloat = 56
    static let labelMaxWidth: CGFloat = 96
    static let labelHeight: CGFloat = 24
    static let textGap: CGFloat = 0
    static let horizontalEdgePadding: CGFloat = 0
    
    static var reservedColumnWidth: CGFloat {
        labelMaxWidth + textGap + horizontalEdgePadding
    }
}


