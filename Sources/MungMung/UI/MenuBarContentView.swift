import SwiftUI

struct MenuBarContentView: View {
    @Bindable var viewModel: AlertViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.alerts.isEmpty {
                emptyState
            } else {
                alertList
            }
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No pending alerts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var alertList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.alerts) { alert in
                    AlertRowView(
                        alert: alert,
                        onDismiss: { viewModel.dismiss(alert) },
                        onRun: (alert.onClick != nil && !(alert.onClick?.isEmpty ?? true))
                            ? { viewModel.run(alert) }
                            : nil
                    )
                    .padding(.horizontal, 12)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 400)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if !viewModel.alerts.isEmpty {
                HStack {
                    Text("\(viewModel.alerts.count) alert\(viewModel.alerts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear All") {
                        viewModel.clearAll()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            }

            Button {
                openSettings()
            } label: {
                HStack {
                    Text("Settings...")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverButtonStyle())

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit MungMung")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverButtonStyle())
        }
    }
}

private struct HoverButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            .onHover { isHovered = $0 }
    }
}
