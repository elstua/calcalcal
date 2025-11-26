import UIKit

enum CalorieOverlayMetrics {
    static let labelMinWidth: CGFloat = 56
    static let labelMaxWidth: CGFloat = 96
    static let textGap: CGFloat = 24
    static let horizontalEdgePadding: CGFloat = 12
    
    static var reservedColumnWidth: CGFloat {
        labelMaxWidth + textGap + horizontalEdgePadding
    }
}


