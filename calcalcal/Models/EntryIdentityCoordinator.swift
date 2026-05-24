import Combine
import Foundation

struct EntryCanonicalization {
    let localId: UUID
    let serverId: UUID
}

/// Centralized helper that keeps diary entry identifiers in sync between
/// locally generated placeholder IDs and the canonical IDs returned by the backend.
/// It also migrates any disk caches (blocks + images) so reopening the app does not
/// lose locally captured content such as photos.
final class EntryIdentityCoordinator {
    static let shared = EntryIdentityCoordinator()
    let canonicalizations = PassthroughSubject<EntryCanonicalization, Never>()
    private init() {}
    
    /// Update caches and broadcast that a placeholder entry has been assigned a canonical server ID.
    /// - Parameters:
    ///   - localId: The temporary UUID used before the entry exists on the server.
    ///   - serverId: The UUID returned by the backend once the entry is persisted.
    ///   - blocks: Current blocks for the entry so we can migrate image caches.
    func canonicalize(localId: UUID, serverId: UUID, blocks: [Block]) {
        guard localId != serverId else { return }
        
        BlocksCache.shared.migrateEntry(from: localId, to: serverId)
        
        let imageRefs = blocks.compactMap { block -> UUID? in
            if case let .imageText(_, ref, _) = block.type {
                return ref
            }
            return nil
        }
        ImageCache.shared.promoteLegacyLocalImages(from: localId, refs: imageRefs)
        
        DispatchQueue.main.async {
            self.canonicalizations.send(EntryCanonicalization(localId: localId, serverId: serverId))
        }
    }
}
