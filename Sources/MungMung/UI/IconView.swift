import SwiftUI

/// Displays an icon from emoji, SF Symbol name, or image file path.
///
/// Uses `IconRenderer.detect` to auto-detect the icon type and renders accordingly.
struct IconView: View {
    let icon: String
    var size: CGFloat = 24

    var body: some View {
        switch IconRenderer.detect(icon) {
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)

        case .imageFile(let path):
            let expandedPath = NSString(string: path).expandingTildeInPath
            if let nsImage = NSImage(contentsOfFile: expandedPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Text(icon)
                    .font(.system(size: size * 0.75))
            }

        case .emoji(let text):
            Text(text)
                .font(.system(size: size * 0.75))
        }
    }
}
