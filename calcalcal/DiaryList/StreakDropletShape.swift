import SwiftUI
import UIKit

/// Custom shape representing a droplet/flame-like teardrop
/// Used in the streak button to visualize streak progress
struct StreakDropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start at the top center
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        
        // Right curve - using control points for smooth bezier curve
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.7),
            control1: CGPoint(x: width * 0.85, y: height * 0.15),
            control2: CGPoint(x: width, y: height * 0.45)
        )
        
        // Bottom curve - rounded bottom
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width * 0.85, y: height * 0.95),
            control2: CGPoint(x: width * 0.65, y: height)
        )
        
        // Left curve - mirror of right side
        path.addCurve(
            to: CGPoint(x: 0, y: height * 0.7),
            control1: CGPoint(x: width * 0.35, y: height),
            control2: CGPoint(x: 0, y: height * 0.95)
        )
        
        // Close the path back to top
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: 0),
            control1: CGPoint(x: 0, y: height * 0.45),
            control2: CGPoint(x: width * 0.15, y: height * 0.15)
        )
        
        return path
    }
}

// MARK: - Preview
struct StreakDropletShape_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreakDropletShape()
                .fill(DSColors.secondary)
                .frame(width: 60, height: 80)
            
            HStack(spacing: 10) {
                StreakDropletShape()
                    .fill(DSColors.secondary.opacity(0.8))
                    .frame(width: 40, height: 55)
                
                StreakDropletShape()
                    .fill(DSColors.secondary.opacity(0.6))
                    .frame(width: 35, height: 48)
            }
        }
        .padding()
        .background(DSColors.background)
    }
}
