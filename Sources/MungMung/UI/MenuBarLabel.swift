import SwiftUI

struct MenuBarLabel: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            menuBarIcon
            if count > 0 {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .offset(x: 2, y: -2)
            }
        }
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
