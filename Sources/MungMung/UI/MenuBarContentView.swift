import AppKit
import SwiftUI

struct MenuBarContentView: View {
    private enum TransitionState {
        case menuOpen
        case transitioningToSettings
        case settingsOpen
    }

    @Bindable var viewModel: AlertViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var transitionState: TransitionState = .menuOpen
    @State private var settingsTransitionWorkItem: DispatchWorkItem?
    private let settingsTransitionFallbackDelay: TimeInterval = 0.2

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
            transitionState = .menuOpen
            cancelSettingsTransitionFallback()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
            if transitionState == .transitioningToSettings {
                openSettingsAfterMenuClose()
            }
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
                requestSettingsTransition()
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

    private func requestSettingsTransition() {
        guard transitionState == .menuOpen else { return }

        transitionState = .transitioningToSettings
        startSettingsTransitionFallback()

        dismiss()
        NSApp.keyWindow?.performClose(nil)
    }

    private func startSettingsTransitionFallback() {
        cancelSettingsTransitionFallback()

        let workItem = DispatchWorkItem {
            openSettingsAfterMenuClose()
        }

        settingsTransitionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + settingsTransitionFallbackDelay, execute: workItem)
    }

    private func cancelSettingsTransitionFallback() {
        settingsTransitionWorkItem?.cancel()
        settingsTransitionWorkItem = nil
    }

    private func openSettingsAfterMenuClose() {
        guard transitionState == .transitioningToSettings else { return }

        cancelSettingsTransitionFallback()
        transitionState = .settingsOpen
        openSettings()
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
