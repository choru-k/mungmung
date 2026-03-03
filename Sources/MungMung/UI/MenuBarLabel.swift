import SwiftUI

struct MenuBarLabel: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            menuBarIcon
            if count > 0 {
                Text(badgeText)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .frame(minWidth: 12, minHeight: 12)
                    .background(Capsule().fill(.red))
                    .offset(x: 8, y: -4)
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
