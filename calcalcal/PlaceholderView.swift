import SwiftUI

struct PlaceholderView: View {
    var body: some View {
        Text("Start to write what you eat...")
            .foregroundColor(.gray)
            .font(.system(size: 18))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, LayoutConstants.textEditorPadding.leading)
    }
}
