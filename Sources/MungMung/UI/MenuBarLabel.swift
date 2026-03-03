import SwiftUI

struct MenuBarLabel: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            menuBarIcon
            if count > 0 {
                Text(badgeText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 14)
                    .background(Capsule().fill(.red))
                    .accessibilityLabel("\(count) pending alerts")
            }
        }
    }

    private var badgeText: String {
        count > 99 ? "99+" : "\(count)"
    }

    private var menuBarIcon: some View {
        let image: NSImage = {
            if let img = Bundle.main.image(forResource: "MenuBarIcon") {
                img.isTemplate = true
                return img
            }
            return NSImage(systemSymbolName: "bell", accessibilityDescription: "MungMung")!
        }()
        return Image(nsImage: image)
    }
}
