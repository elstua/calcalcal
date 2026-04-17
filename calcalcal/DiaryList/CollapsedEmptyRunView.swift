import SwiftUI
import Foundation

struct CollapsedEmptyRunView: View {
	let primaryText: String
	let secondaryText: String
	var onExpand: (() -> Void)? = nil

	var body: some View {
		Button(action: { onExpand?() }) {
			HStack(alignment: .center, spacing: DSSpacing.smd) {
		Image(systemName: "chevron.down.circle.fill")
			.font(.dsTitle3)
				.foregroundColor(DSColors.textSecondary)
				VStack(alignment: .leading, spacing: DSSpacing.xxs) {
			Text(primaryText)
				.font(.dsBodyEmphasized)
					.foregroundColor(DSColors.textPrimary)
			Text(secondaryText)
				.font(.dsCaption)
					.foregroundColor(DSColors.textSecondary)
				}
				Spacer()
		Image(systemName: "chevron.right")
			.font(.dsSubheadline)
				.foregroundColor(DSColors.textSecondary)
			}
		.padding(.vertical, DSSpacing.smd)
		.padding(.horizontal, DSSpacing.md)
		.background(DSColors.surface)
		.cornerRadius(DSCornerRadius.lg)
			.shadow(color: DSColors.shadowLight, radius: 4, x: 0, y: 2)
		}
		.buttonStyle(PlainButtonStyle())
	}
}

struct CollapsedEmptyRunView_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: DSSpacing.md) {
			CollapsedEmptyRunView(primaryText: "17 days, Sep 1–17", secondaryText: "Tap to show 14 more days", onExpand: {})
				.padding(.horizontal)
		}
		.background(DSColors.background)
	}
}


