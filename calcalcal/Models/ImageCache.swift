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
    
    private func fileURL(for url: String) -> URL {
        return cacheDirectory().appendingPathComponent(key(for: url)).appendingPathExtension("img")
    }
    
    func imageIfCached(for url: String) -> UIImage? {
        if let img = memoryCache[url] { return img }
        let path = fileURL(for: url).path
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let img = UIImage(data: data) {
            memoryCache[url] = img
            return img
        }
        return nil
    }
    
    func store(_ image: UIImage, for url: String) {
        memoryCache[url] = image
        ioQueue.async {
            if let data = image.pngData() {
                try? data.write(to: self.fileURL(for: url), options: .atomic)
            }
        }
    }
    
    func fetch(_ urlString: String) async -> UIImage? {
        if let cached = imageIfCached(for: urlString) {
            return cached
        }
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let image = UIImage(data: data) {
                store(image, for: urlString)
                return image
            }
        } catch {
            return nil
        }
        return nil
    }
}


