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
                                    totalCalories: entry.totalCalories,
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
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .onChange(of: blocks) { newValue in
                                scheduleAutosave(blocks: newValue)
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
                                    totalCalories: entry.totalCalories,
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
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .onChange(of: blocks) { newValue in
                                scheduleAutosave(blocks: newValue)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                useMatchedGeometry = false
            }
        }
        .onDisappear {
            flushSave()
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
            print("✅ Autosave success at \(lastSavedAt?.description ?? "now")")
        } catch {
            print("❌ Autosave error: \(error)")
        }
    }
}


