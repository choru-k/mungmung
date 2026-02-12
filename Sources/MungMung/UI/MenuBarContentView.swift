import SwiftUI

struct MenuBarContentView: View {
    @Bindable var viewModel: AlertViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.alerts.isEmpty {
                emptyState
            } else {
                alertList
                Divider()
                footer
            }
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
                    AlertRowView(alert: alert) {
                        viewModel.dismiss(alert)
                    }
                    .padding(.horizontal, 12)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 400)
    }

    private var footer: some View {
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
        .padding(.vertical, 8)
    }
}
