import SwiftUI
import UIKit

struct EditorOverlay: View {
    let entry: DiaryEntry
    @Binding var blocks: [Block]
    @Binding var shouldBecomeFirstResponder: Bool
    let namespace: Namespace.ID
    let onClose: () -> Void
    
    @State private var showImagePicker: Bool = false
    @State private var pickedImage: UIImage? = nil
    @GestureState private var dragOffset: CGSize = .zero
    @State private var hasDismissedKeyboardForDrag: Bool = false
    @State private var useMatchedGeometry: Bool = true
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var lastSavedAt: Date? = nil
    @State private var lastSavedContent: String? = nil
    @State private var liveTotalCalories: Int? = nil
    @State private var suppressRemoteBlockUpdates: Bool = false
    @State private var pendingRemoteBlocks: [Block]? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            // Dimmed background with interactive opacity
            let progress = min(1.0, max(0.0, 1.0 - (dragOffset.height / 400.0)))
            Color.black.opacity(0.35 * progress)
                .ignoresSafeArea()
                .onTapGesture { dismissWithMatched() }
            
            // Wrapper that responds to keyboard. Keep matched view inside for stable geometry.
            VStack(spacing: 0) {
                Group {
                    if useMatchedGeometry {
                        VStack(spacing: 0) {
                            BigEntryBlock(
                                entry: DiaryEntry(
                                    id: entry.id,
                                    date: entry.date,
                                    blocks: blocks,
                                    totalCalories: liveTotalCalories ?? entry.totalCalories,
                                    lastModified: entry.lastModified,
                                    aiGeneratedSummary: entry.aiGeneratedSummary
                                ),
                                height: .infinity,
                                cornerRadius: 0,
                                showShadow: false,
                                useExternalDecoration: true,
                                onAddImage: { showImagePicker = true },
                                onTap: {},
                                imageMap: [:],
                                isEditable: true,
                                shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                                forceExpanded: true,
                                onBlocksChange: { updated in
                                    blocks = updated
                                },
                                overrideTotalCalories: liveTotalCalories ?? entry.totalCalories
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .onChange(of: blocks) { newValue in
                                scheduleAutosaveIfTextChanged(blocks: newValue)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 0, style: .continuous)
                                .fill(Color(.systemBackground))
                                .matchedGeometryEffect(id: "bg-\(entry.id)", in: namespace, isSource: false)
                        )
                        .matchedGeometryEffect(id: entry.id, in: namespace, isSource: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        VStack(spacing: 0) {
                            BigEntryBlock(
                                entry: DiaryEntry(
                                    id: entry.id,
                                    date: entry.date,
                                    blocks: blocks,
                                    totalCalories: liveTotalCalories ?? entry.totalCalories,
                                    lastModified: entry.lastModified,
                                    aiGeneratedSummary: entry.aiGeneratedSummary
                                ),
                                height: .infinity,
                                cornerRadius: 0,
                                showShadow: false,
                                useExternalDecoration: true,
                                onAddImage: { showImagePicker = true },
                                onTap: {},
                                imageMap: [:],
                                isEditable: true,
                                shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                                forceExpanded: true,
                                onBlocksChange: { updated in
                                    blocks = updated
                                },
                                overrideTotalCalories: liveTotalCalories ?? entry.totalCalories
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .onChange(of: blocks) { newValue in
                                scheduleAutosaveIfTextChanged(blocks: newValue)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 0, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
            }
            .offset(y: max(0, dragOffset.height))
            .overlay(alignment: .topTrailing) {
                // Close button
                Button(action: { dismissWithMatched() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .padding(12)
                }
                .padding(.top, 4)
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                        if value.translation.height > 8 && !hasDismissedKeyboardForDrag {
                            // Dismiss keyboard to avoid awkward lift during drag
                            shouldBecomeFirstResponder = false
                            hasDismissedKeyboardForDrag = true
                        }
                    }
                    .onEnded { value in
                        let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 180
                        if shouldDismiss {
                            dismissWithMatched()
                        } else {
                            // Restore focus if we had dismissed it for drag
                            if hasDismissedKeyboardForDrag {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    shouldBecomeFirstResponder = true
                                    hasDismissedKeyboardForDrag = false
                                }
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $pickedImage)
                .onDisappear {
                    guard let image = pickedImage else { return }
                    let uuid = UUID()
                    // image map can be passed down later if needed
                    if let data = image.pngData() {
                        // Append as imageText block with empty text to encourage typing
                        blocks.append(Block(type: .imageText(data, uuid, ""), calorieData: nil))
                    }
                    // Ensure keyboard focuses after insert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldBecomeFirstResponder = true
                    }
                    pickedImage = nil
                }
        }
        .onAppear {
            // Allow matched geometry during the opening transition, then detach
            useMatchedGeometry = true
            liveTotalCalories = entry.totalCalories
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                useMatchedGeometry = false
            }
            // Fetch existing per-block calories for this entry (if already analyzed)
            Task {
                do {
                    let dbBlocks = try await DiaryAPI.getBlocksById(entry.id.uuidString)
                    await MainActor.run {
                        var updated = blocks
                        var i = 0
                        for idx in updated.indices {
                            switch updated[idx].type {
                            case .text(let t):
                                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    if i < dbBlocks.count {
                                        let kcal = dbBlocks[i].calories ?? 0
                                        updated[idx].calorieData = kcal > 0 ? "\(kcal)" : nil
                                        updated[idx].nutrition = NutritionData(
                                            calories: dbBlocks[i].calories,
                                            protein: dbBlocks[i].protein,
                                            fat: dbBlocks[i].fat,
                                            carbs: dbBlocks[i].carbs,
                                            fiber: dbBlocks[i].fiber,
                                            sugar: dbBlocks[i].sugar,
                                            sodium: dbBlocks[i].sodium,
                                            confidence: dbBlocks[i].confidence
                                        )
                                    }
                                    i += 1
                                }
                            case .imageText(_, _, let t):
                                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    if i < dbBlocks.count {
                                        let kcal = dbBlocks[i].calories ?? 0
                                        updated[idx].calorieData = kcal > 0 ? "\(kcal)" : nil
                                        updated[idx].nutrition = NutritionData(
                                            calories: dbBlocks[i].calories,
                                            protein: dbBlocks[i].protein,
                                            fat: dbBlocks[i].fat,
                                            carbs: dbBlocks[i].carbs,
                                            fiber: dbBlocks[i].fiber,
                                            sugar: dbBlocks[i].sugar,
                                            sodium: dbBlocks[i].sodium,
                                            confidence: dbBlocks[i].confidence
                                        )
                                    }
                                    i += 1
                                }
                            default:
                                break
                            }
                        }
                        // Apply per-block metadata (calories, nutrition) live; content remains user source of truth
                        self.blocks = updated
                    }
                } catch {
                    // Best-effort; ignore if blocks not available yet
                }
            }
            // Initialize lastSavedContent to current textual content to avoid initial autosave loop
            let initial = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
            lastSavedContent = initial
        }
        .onDisappear {
            flushSave()
            // Apply any queued remote updates only after editor closes
            if let pending = pendingRemoteBlocks {
                blocks = pending
                pendingRemoteBlocks = nil
            }
            suppressRemoteBlockUpdates = false
        }
    }
}

// MARK: - UIKit image picker wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

extension Notification.Name {
    static let editorOverlayDidCommit = Notification.Name("editorOverlayDidCommit")
}

// MARK: - Private helpers
extension EditorOverlay {
    private func dismissWithMatched() {
        // Re-enable matched geometry just before closing to allow a smooth return animation
        useMatchedGeometry = true
        onClose()
    }
}

// MARK: - Autosave helpers
extension EditorOverlay {
    private func scheduleAutosaveIfTextChanged(blocks: [Block]) {
        let content = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        if content == lastSavedContent {
            print("⏭️ Autosave skipped (text unchanged)")
            return
        }
        scheduleAutosave(blocks: blocks)
    }

    private func scheduleAutosave(blocks: [Block]) {
        debounceWorkItem?.cancel()
        print("🕐 Autosave scheduled in 1s…")
        let workItem = DispatchWorkItem {
            print("💾 Autosave firing…")
            Task { await save(blocks: blocks) }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func flushSave() {
        if let work = debounceWorkItem {
            work.cancel()
            debounceWorkItem = nil
        }
        print("🔚 Flushing autosave on close…")
        Task { await save(blocks: blocks) }
    }

    private func save(blocks: [Block]) async {
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = [
            "write what you ate today",
            "write what you ate this day"
        ]
        if trimmed.isEmpty || placeholders.contains(trimmed) {
            print("⏭️ Autosave skipped (empty/placeholder content)")
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offsetMinutes)
        print("⬆️ Upserting content for day \(day)… (overlay)")
        do {
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content)
                // Trigger AI analysis after successful upsert
                let payload = blocks.toAnalyzeBlocks()
                if !payload.isEmpty {
                    Task.detached {
                        do {
                            _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)
                            print("🤖 Analyze triggered for entry \(row.id) with \(payload.count) blocks")
                            // Poll for updated totals and per-block calories after analysis completes (simple backoff up to ~6s)
                            for delay in [0.8, 1.2, 2.0, 2.8] {
                                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                let refreshed = try? await DiaryAPI.getById(row.id)
                                let dbBlocks = try? await DiaryAPI.getBlocksById(row.id)
                                await MainActor.run {
                                    if let refreshed {
                                        NotificationCenter.default.post(
                                            name: .diaryEntryTotalsUpdated,
                                            object: nil,
                                            userInfo: [
                                                "entryId": entry.id,
                                                "totalCalories": refreshed.total_calories as Any
                                            ]
                                        )
                                        self.liveTotalCalories = refreshed.total_calories ?? self.liveTotalCalories
                                    }
                                    if let dbBlocks {
                                        var updated = blocks
                                        var i = 0
                                        for idx in updated.indices {
                                            switch updated[idx].type {
                                            case .text(let t):
                                                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !trimmed.isEmpty {
                                                    if i < dbBlocks.count {
                                                        let kcal = dbBlocks[i].calories ?? 0
                                                        updated[idx].calorieData = kcal > 0 ? "\(kcal)" : nil
                                                        updated[idx].nutrition = NutritionData(
                                                            calories: dbBlocks[i].calories,
                                                            protein: dbBlocks[i].protein,
                                                            fat: dbBlocks[i].fat,
                                                            carbs: dbBlocks[i].carbs,
                                                            fiber: dbBlocks[i].fiber,
                                                            sugar: dbBlocks[i].sugar,
                                                            sodium: dbBlocks[i].sodium,
                                                            confidence: dbBlocks[i].confidence
                                                        )
                                                    }
                                                    i += 1
                                                }
                                            case .imageText(_, _, let t):
                                                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !trimmed.isEmpty {
                                                    if i < dbBlocks.count {
                                                        let kcal = dbBlocks[i].calories ?? 0
                                                        updated[idx].calorieData = kcal > 0 ? "\(kcal)" : nil
                                                        updated[idx].nutrition = NutritionData(
                                                            calories: dbBlocks[i].calories,
                                                            protein: dbBlocks[i].protein,
                                                            fat: dbBlocks[i].fat,
                                                            carbs: dbBlocks[i].carbs,
                                                            fiber: dbBlocks[i].fiber,
                                                            sugar: dbBlocks[i].sugar,
                                                            sodium: dbBlocks[i].sodium,
                                                            confidence: dbBlocks[i].confidence
                                                        )
                                                    }
                                                    i += 1
                                                }
                                            default:
                                                break
                                            }
                                        }
                                        // Apply metadata updates live to show calorie labels updating
                                        self.blocks = updated
                                    }
                                }
                                if let refreshed = refreshed, let cals = refreshed.total_calories, cals > 0 { break }
                            }
                        } catch {
                            print("❌ Analyze error: \(error)")
                        }
                    }
                }
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .diaryEntryTotalsUpdated,
                        object: nil,
                        userInfo: [
                            "entryId": entry.id,
                            "totalCalories": row.total_calories as Any
                        ]
                    )
                }
            } else {
                print("⚠️ Missing user id; deferring insert until available")
            }
            lastSavedAt = Date()
            lastSavedContent = trimmed
            print("✅ Autosave success at \(lastSavedAt?.description ?? "now")")
        } catch {
            print("❌ Autosave error: \(error)")
        }
    }
}


