import SwiftUI

/// About App screen - shows a carousel of 3 feature highlights.
/// Uses TabView with PageTabViewStyle for horizontal swiping.
struct AboutAppStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var currentPage = 0
    
    // Feature data
    private let features: [FeatureItem] = [
        FeatureItem(
            icon: "text.bubble.fill",
            title: "Natural Language Input",
            description: "Just describe what you ate in your own words. No need to search databases or scan barcodes.",
            color: .blue
        ),
        FeatureItem(
            icon: "brain.head.profile",
            title: "AI-Powered Counting",
            description: "Our AI understands portions, ingredients, and cooking methods to give you accurate calorie estimates.",
            color: .purple
        ),
        FeatureItem(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Progress",
            description: "See your daily intake, track trends over time, and reach your health goals.",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Carousel
            TabView(selection: $currentPage) {
                ForEach(0..<features.count, id: \.self) { index in
                    featureCard(features[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 400)
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<features.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            
            Spacer()
            
            // Navigation
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        _ = coordinator.advance(.next)
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    withAnimation {
                        _ = coordinator.advance(.goBack)
                    }
                }) {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Feature Card
    
    private func featureCard(_ feature: FeatureItem) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 50))
                    .foregroundColor(feature.color)
            }
            
            // Text
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// MARK: - Feature Item Model

private struct FeatureItem {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Preview


struct AboutAppStepView_Previews: PreviewProvider {
    static var previews: some View {
        AboutAppStepView(coordinator: OnboardingCoordinator())
    }
}

