import Foundation

final class BlocksCache {
    static let shared = BlocksCache()
    private init() {}

    private let ioQueue = DispatchQueue(label: "blocks-cache-io")

    private func cacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BlocksCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    private func fileURL(for entryId: UUID) -> URL {
        return cacheDirectory().appendingPathComponent(entryId.uuidString).appendingPathExtension("json")
    }

    // MARK: - DTOs
    private struct CachedNutritionData: Codable {
        var calories: Int?
        var protein: Double?
        var fat: Double?
        var carbs: Double?
        var fiber: Double?
        var sugar: Double?
        var sodium: Double?
        var weight: Double?
        var metric_description: String?
        var confidence: Double?
    }

    private struct CachedBlock: Codable {
        var id: String?
        var type: String // "text" | "imageText" | "spacer"
        var text: String?
        var imageRef: String?
        var calorieData: String?
        var nutrition: CachedNutritionData?
        var imageUrl: String?
        var imageObjectKey: String?
    }

    private struct CachedEntry: Codable {
        var entryId: String
        var updatedAt: String
        var blocks: [CachedBlock]
    }

    private func encodeBlocks(_ blocks: [Block]) -> [CachedBlock] {
        return blocks.map { block in
            switch block.type {
            case .text(let text):
                return CachedBlock(
                    id: block.id.uuidString,
                    type: "text",
                    text: text,
                    imageRef: nil,
                    calorieData: block.calorieData,
                    nutrition: block.nutrition.map { n in
                        CachedNutritionData(
                            calories: n.calories,
                            protein: n.protein,
                            fat: n.fat,
                            carbs: n.carbs,
                            fiber: n.fiber,
                            sugar: n.sugar,
                            sodium: n.sodium,
                            weight: n.weight,
                            metric_description: n.metric_description,
                            confidence: n.confidence
                        )
                    },
                    imageUrl: block.imageUrl,
                    imageObjectKey: block.imageObjectKey
                )
            case .imageText(_, let ref, let text):
                return CachedBlock(
                    id: block.id.uuidString,
                    type: "imageText",
                    text: text,
                    imageRef: ref.uuidString,
                    calorieData: block.calorieData,
                    nutrition: block.nutrition.map { n in
                        CachedNutritionData(
                            calories: n.calories,
                            protein: n.protein,
                            fat: n.fat,
                            carbs: n.carbs,
                            fiber: n.fiber,
                            sugar: n.sugar,
                            sodium: n.sodium,
                            weight: n.weight,
                            metric_description: n.metric_description,
                            confidence: n.confidence
                        )
                    },
                    imageUrl: block.imageUrl,
                    imageObjectKey: block.imageObjectKey
                )
            case .image:
                // Editor currently normalizes to imageText; persist as imageText with empty text
                return CachedBlock(
                    id: block.id.uuidString,
                    type: "imageText",
                    text: "",
                    imageRef: UUID().uuidString,
                    calorieData: block.calorieData,
                    nutrition: block.nutrition.map { n in
                        CachedNutritionData(
                            calories: n.calories,
                            protein: n.protein,
                            fat: n.fat,
                            carbs: n.carbs,
                            fiber: n.fiber,
                            sugar: n.sugar,
                            sodium: n.sodium,
                            weight: n.weight,
                            metric_description: n.metric_description,
                            confidence: n.confidence
                        )
                    },
                    imageUrl: block.imageUrl,
                    imageObjectKey: block.imageObjectKey
                )
            case .spacer:
                return CachedBlock(
                    id: block.id.uuidString,
                    type: "spacer",
                    text: nil,
                    imageRef: nil,
                    calorieData: nil,
                    nutrition: nil,
                    imageUrl: nil,
                    imageObjectKey: nil
                )
            }
        }
    }

    private func decodeBlocks(_ cached: [CachedBlock]) -> [Block] {
        return cached.compactMap { cb in
            switch cb.type {
            case "text":
                return Block(
                    type: .text(cb.text ?? ""),
                    calorieData: cb.calorieData,
                    nutrition: cb.nutrition.map { n in
                        NutritionData(
                            calories: n.calories,
                            protein: n.protein,
                            fat: n.fat,
                            carbs: n.carbs,
                            fiber: n.fiber,
                            sugar: n.sugar,
                            sodium: n.sodium,
                            confidence: n.confidence
                        )
                    },
                    imageUrl: cb.imageUrl,
                    imageObjectKey: cb.imageObjectKey,
                    stableId: nil
                )
            case "imageText":
                if let sref = cb.imageRef, let ref = UUID(uuidString: sref) {
                    var block = Block(
                        type: .imageText(Data(), ref, cb.text ?? ""),
                        calorieData: cb.calorieData,
                        nutrition: cb.nutrition.map { n in
                            NutritionData(
                                calories: n.calories,
                                protein: n.protein,
                                fat: n.fat,
                                carbs: n.carbs,
                                fiber: n.fiber,
                                sugar: n.sugar,
                                sodium: n.sodium,
                                confidence: n.confidence
                            )
                        }
                    )
                    block.imageUrl = cb.imageUrl
                    block.imageObjectKey = cb.imageObjectKey
                    return block
                } else {
                    return Block(type: .text(cb.text ?? ""), calorieData: cb.calorieData)
                }
            case "spacer":
                return Block(type: .spacer, calorieData: nil, nutrition: nil)
            default:
                return nil
            }
        }
    }

    // MARK: - API
    func save(entryId: UUID, blocks: [Block]) {
        let url = fileURL(for: entryId)
        let dto = CachedEntry(
            entryId: entryId.uuidString,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            blocks: encodeBlocks(blocks)
        )
        DataFlowLogger.shared.cacheSaveStarted(
            entryId: entryId, 
            blockCount: blocks.count, 
            contentPreview: DataFlowLogger.preview(from: blocks)
        )
        ioQueue.async {
            do {
                let data = try JSONEncoder().encode(dto)
                try data.write(to: url, options: .atomic)
                DataFlowLogger.shared.cacheSaveCompleted(entryId: entryId)
            } catch {
                DataFlowLogger.shared.cacheSaveFailed(entryId: entryId, error: error.localizedDescription)
            }
        }
    }
    
    /// Synchronous save - waits for completion before returning
    func saveSync(entryId: UUID, blocks: [Block]) {
        let url = fileURL(for: entryId)
        let dto = CachedEntry(
            entryId: entryId.uuidString,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            blocks: encodeBlocks(blocks)
        )
        DataFlowLogger.shared.cacheSaveStarted(
            entryId: entryId, 
            blockCount: blocks.count, 
            contentPreview: DataFlowLogger.preview(from: blocks)
        )
        ioQueue.sync {
            do {
                let data = try JSONEncoder().encode(dto)
                try data.write(to: url, options: .atomic)
                DataFlowLogger.shared.cacheSaveCompleted(entryId: entryId)
            } catch {
                DataFlowLogger.shared.cacheSaveFailed(entryId: entryId, error: error.localizedDescription)
            }
        }
    }

    func load(entryId: UUID) -> [Block]? {
        DataFlowLogger.shared.cacheLoadStarted(entryId: entryId)
        
        let url = fileURL(for: entryId)
        guard let data = try? Data(contentsOf: url) else { 
            DataFlowLogger.shared.cacheLoadMissing(entryId: entryId)
            return nil 
        }
        guard let dto = try? JSONDecoder().decode(CachedEntry.self, from: data) else { 
            DataFlowLogger.shared.cacheLoadFailed(entryId: entryId, reason: "decode failed")
            return nil 
        }
        guard dto.entryId == entryId.uuidString else { 
            DataFlowLogger.shared.cacheLoadFailed(entryId: entryId, reason: "ID mismatch")
            return nil 
        }
        let blocks = decodeBlocks(dto.blocks)
        DataFlowLogger.shared.cacheLoadSuccess(
            entryId: entryId, 
            blockCount: blocks.count, 
            contentPreview: DataFlowLogger.preview(from: blocks)
        )
        return blocks
    }

    /// Rename/migrate cached blocks when a placeholder entry receives its canonical server id.
    func migrateEntry(from oldId: UUID, to newId: UUID) {
        guard oldId != newId else { return }
        ioQueue.async {
            let fm = FileManager.default
            let oldURL = self.fileURL(for: oldId)
            let newURL = self.fileURL(for: newId)
            guard fm.fileExists(atPath: oldURL.path) else { return }

            let decoder = JSONDecoder()
            let isoFormatter = ISO8601DateFormatter()

            do {
                if fm.fileExists(atPath: newURL.path) {
                    let oldData = try Data(contentsOf: oldURL)
                    let newData = try Data(contentsOf: newURL)
                    let oldEntry = try decoder.decode(CachedEntry.self, from: oldData)
                    let newEntry = try decoder.decode(CachedEntry.self, from: newData)
                    let oldDate = isoFormatter.date(from: oldEntry.updatedAt) ?? .distantPast
                    let newDate = isoFormatter.date(from: newEntry.updatedAt) ?? .distantPast

                    if oldDate > newDate {
                        try fm.removeItem(at: newURL)
                        try oldData.write(to: newURL, options: .atomic)
                    }
                    try? fm.removeItem(at: oldURL)
                } else {
                    try fm.moveItem(at: oldURL, to: newURL)
                }
            } catch {
                if !fm.fileExists(atPath: newURL.path) {
                    try? fm.copyItem(at: oldURL, to: newURL)
                }
                try? fm.removeItem(at: oldURL)
            }
        }
    }
}
