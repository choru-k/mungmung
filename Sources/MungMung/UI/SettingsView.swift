import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Picker("Polling Interval", selection: $settings.pollingInterval) {
                    ForEach(AppSettings.pollingIntervalOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Notification Sound", isOn: $settings.soundEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
    }
}
