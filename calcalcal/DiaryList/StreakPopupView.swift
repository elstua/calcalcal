import SwiftUI
import UIKit

/// Custom bottom popup view for displaying streak statistics
/// Shows current streak and longest streak with swipe-to-close
struct StreakPopupView: View {
    let streaksData: StreaksData?
    let onClose: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    private let dragThreshold: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 24)
                .fill(DSColors.textSecondary.opacity(0.2))
                .frame(width: 48, height: 3)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Content
            VStack(spacing: 24) {
                // Current Streak Section
                VStack(spacing: 4) {
                    Text("\(streaksData?.currentStreak ?? 0)")
                        .dsTypography(.display)
                        .foregroundColor(DSColors.secondary)
                    
                    Text("Days you've been consistent")
                        .dsTypography(.body)
                        .foregroundColor(DSColors.textSecondary)
                }
                
                Divider()
                    
                
                // Longest Streak Section
                HStack(spacing: 12) {
                    Text("Best Streak")
                        .dsTypography(.body)
                        .foregroundColor(DSColors.textSecondary)
                    Spacer()
                    Text("\(streaksData?.longestStreak ?? 0)")
                        .dsTypography(.title2)
                        .foregroundColor(DSColors.textSecondary)
                }
                
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(DSColors.surface)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0)
        )
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    // Only allow dragging down
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let velocity = value.predictedEndLocation.y - value.location.y
                    
                    // Close if dragged past threshold or with enough velocity
                    if dragOffset > dragThreshold || velocity > 300 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = UIScreen.main.bounds.height
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onClose()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
    }
}

// MARK: - Streak Popup Container
/// Container view that manages the popup presentation with dimmed background
struct StreakPopupContainer: View {
    let streaksData: StreaksData?
    let isPresented: Bool
    let onClose: () -> Void
    
    @State private var backgroundOpacity: Double = 0
    @State private var popupOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Dimmed background
                DSColors.background
                    .opacity(0.8) // Almost transparent to catch taps
                    .background(DSColors.background.edgesIgnoringSafeArea(.all))
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePopup()
                    }
                
                // Popup content
                StreakPopupView(streaksData: streaksData, onClose: onClose)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .offset(y: popupOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onChange(of: isPresented) { newValue in
                if newValue {
                    presentPopup()
                } else {
                    dismissPopup()
                }
            }
            .onAppear {
                if isPresented {
                    presentPopup()
                }
            }
        }
    }
    
    private func presentPopup() {
        popupOffset = UIScreen.main.bounds.height
        backgroundOpacity = 0
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            popupOffset = 0
            backgroundOpacity = 0.5
        }
    }
    
    private func dismissPopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            popupOffset = UIScreen.main.bounds.height
            backgroundOpacity = 0
        }
    }
    
    private func closePopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            popupOffset = UIScreen.main.bounds.height
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onClose()
        }
    }
}

// MARK: - Preview
struct StreakPopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with data
            ZStack {
                DSColors.background
                    .ignoresSafeArea()
                
                StreakPopupContainer(
                    streaksData: StreaksData(
                        currentStreak: 16,
                        longestStreak: 23,
                        totalDaysWithEntries: 45,
                        lastEntryDate: "2026-02-01",
                        streakStartDate: "2026-01-16"
                    ),
                    isPresented: true,
                    onClose: {}
                )
            }
            .previewDisplayName("With Data")
            
            // Preview with zero streak
            ZStack {
                DSColors.background
                    .ignoresSafeArea()
                
                StreakPopupContainer(
                    streaksData: StreaksData(
                        currentStreak: 0,
                        longestStreak: 5,
                        totalDaysWithEntries: 5,
                        lastEntryDate: nil,
                        streakStartDate: nil
                    ),
                    isPresented: true,
                    onClose: {}
                )
            }
            .previewDisplayName("Zero Streak")
            
            // Preview with no data
            ZStack {
                DSColors.background
                    .ignoresSafeArea()
                
                StreakPopupContainer(
                    streaksData: nil,
                    isPresented: true,
                    onClose: {}
                )
            }
            .previewDisplayName("No Data")
        }
    }
}
