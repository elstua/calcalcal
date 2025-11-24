import Foundation

enum BlockAttributeKeys {
    static let blockIdentifier = NSAttributedString.Key("BlockIdentifierAttribute")
    static let blockKind = NSAttributedString.Key("BlockKindAttribute")
}

extension NSAttributedString {
    func blockID(at location: Int) -> BlockID? {
        guard location < length else { return nil }
        let value = attribute(BlockAttributeKeys.blockIdentifier, at: location, effectiveRange: nil)
        if let uuid = value as? UUID {
            return BlockID(rawValue: uuid)
        }
        return nil
    }
}

