import SwiftUI

struct MenuBarLabel: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Label("\(count)", systemImage: "bell.badge.fill")
        } else {
            Label("MungMung", systemImage: "bell")
        }
    }
}
