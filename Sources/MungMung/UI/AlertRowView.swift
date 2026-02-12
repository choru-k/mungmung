import SwiftUI

struct AlertRowView: View {
    let alert: Alert
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let icon = alert.icon {
                Text(icon)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(alert.age)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
