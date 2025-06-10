import UIKit

protocol BlockLayoutProviding {
    func exclusionPaths(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> [UIBezierPath]
    func calorieLabelFrame(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata, blockFrame: CGRect) -> CGRect?
    func textAreaWidth(in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> CGFloat
} 
