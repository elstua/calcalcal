import SwiftUI
import Foundation

struct CollapsedEmptyRunView: View {
	let primaryText: String
	let secondaryText: String
	var onExpand: (() -> Void)? = nil

	var body: some View {
		Button(action: { onExpand?() }) {
			HStack(alignment: .center, spacing: 12) {
				Image(systemName: "chevron.down.circle.fill")
					.font(.title3)
					.foregroundColor(.secondary)
				VStack(alignment: .leading, spacing: 2) {
					Text(primaryText)
						.font(.body.weight(.semibold))
						.foregroundColor(.primary)
					Text(secondaryText)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				Spacer()
				Image(systemName: "chevron.right")
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
			.padding(.vertical, 14)
			.padding(.horizontal, 16)
			.background(Color.white)
			.cornerRadius(16)
			.shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
		}
		.buttonStyle(PlainButtonStyle())
	}
}

struct CollapsedEmptyRunView_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 16) {
			CollapsedEmptyRunView(primaryText: "17 days, Sep 1–17", secondaryText: "Tap to show 14 more days", onExpand: {})
				.padding(.horizontal)
		}
		.background(Color(.systemGroupedBackground))
	}
}


