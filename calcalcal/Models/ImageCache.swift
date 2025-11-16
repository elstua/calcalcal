import Foundation
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    
    private let ioQueue = DispatchQueue(label: "image-cache-io")
    private var memoryCache: [String: UIImage] = [:] // key: url
    
    private init() {}
    
    private func cacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ImageCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
    
    private func key(for url: String) -> String {
        // Simple hash
        return String(url.hashValue)
    }
    
    private func isLocalKey(_ key: String) -> Bool {
        return key.hasPrefix("local:") || key.hasPrefix("local-ref:")
    }
    
    private func normalize(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        // Preserve local cache keys as-is
        if isLocalKey(trimmed) { return trimmed }
        // Absolute
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return trimmed }
        // Relative → prepend API base
        var base = Configuration.apiURL
        if base.hasSuffix("/") { base.removeLast() }
        if trimmed.hasPrefix("/") {
            return "\(base)\(trimmed)"
        } else {
            return "\(base)/\(trimmed)"
        }
    }
    
    private func stableLocalKey(for ref: UUID) -> String {
        return "local-ref:\(ref.uuidString)"
    }
    
    private func legacyLocalKey(entryId: UUID, ref: UUID) -> String {
        return "local:\(entryId.uuidString):\(ref.uuidString)"
    }
    
    private func fileURL(for url: String) -> URL {
        return cacheDirectory().appendingPathComponent(key(for: url)).appendingPathExtension("img")
    }
    
    func imageIfCached(for url: String) -> UIImage? {
        let normalized = normalize(url)
        if let img = memoryCache[normalized] { return img }
        let path = fileURL(for: normalized).path
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let img = UIImage(data: data) {
            memoryCache[normalized] = img
            return img
        }
        return nil
    }
    
    func storeLocal(_ image: UIImage, ref: UUID) {
        store(image, for: stableLocalKey(for: ref))
    }
    
    func localImage(ref: UUID, legacyEntryId: UUID? = nil) -> UIImage? {
        let stableKey = stableLocalKey(for: ref)
        if let cached = imageIfCached(for: stableKey) { return cached }
        
        if let legacyEntryId {
            let legacyKey = legacyLocalKey(entryId: legacyEntryId, ref: ref)
            if let legacy = imageIfCached(for: legacyKey) {
                store(legacy, for: stableKey)
                ioQueue.async {
                    try? FileManager.default.removeItem(at: self.fileURL(for: self.normalize(legacyKey)))
                }
                return legacy
            }
        }
        return nil
    }
    
    func promoteLegacyLocalImages(from entryId: UUID, refs: [UUID]) {
        guard !refs.isEmpty else { return }
        ioQueue.async {
            for ref in refs {
                let stableKey = self.normalize(self.stableLocalKey(for: ref))
                let legacyKey = self.normalize(self.legacyLocalKey(entryId: entryId, ref: ref))
                
                var alreadyPromoted = false
                DispatchQueue.main.sync {
                    alreadyPromoted = self.memoryCache[stableKey] != nil
                }
                if alreadyPromoted { continue }
                
                let stableURL = self.fileURL(for: stableKey)
                if FileManager.default.fileExists(atPath: stableURL.path) {
                    continue
                }
                
                let legacyURL = self.fileURL(for: legacyKey)
                guard FileManager.default.fileExists(atPath: legacyURL.path),
                      let data = try? Data(contentsOf: legacyURL),
                      let image = UIImage(data: data) else { continue }
                
                DispatchQueue.main.async {
                    self.memoryCache[stableKey] = image
                }
                if let pngData = image.pngData() {
                    try? pngData.write(to: stableURL, options: .atomic)
                }
                try? FileManager.default.removeItem(at: legacyURL)
            }
        }
    }
    
    func store(_ image: UIImage, for url: String) {
        let normalized = normalize(url)
        memoryCache[normalized] = image
        ioQueue.async {
            if let data = image.pngData() {
                try? data.write(to: self.fileURL(for: normalized), options: .atomic)
            }
        }
    }
    
    func fetch(_ urlString: String) async -> UIImage? {
        let normalized = normalize(urlString)
        if let cached = imageIfCached(for: normalized) {
            return cached
        }
        guard let url = URL(string: normalized) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let image = UIImage(data: data) {
                store(image, for: normalized)
                return image
            }
        } catch {
            return nil
        }
        return nil
    }
}


