import SwiftUI

struct UpdatesTab: View {
    @AppStorage("settings.autoCheckUpdates") private var autoCheck: Bool = true
    @State private var lastChecked: Date? = SparkleUpdater.shared.lastUpdateCheckDate
    @State private var status: String = "Up to date as of last check."

    var body: some View {
        Form {
            Section("Update channel") {
                Picker("Channel", selection: .constant("stable")) {
                    Text("Stable").tag("stable")
                    Text("Beta (coming soon)").tag("beta").disabled(true)
                }
                .pickerStyle(.segmented)
            }
            Section("Behavior") {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { new in
                        SparkleUpdater.shared.automaticallyChecksForUpdates = new
                    }
            }
            Section("Status") {
                if let lastChecked {
                    LabeledContent("Last checked", value: lastChecked.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("Last checked", value: "Never")
                }
                Text(status).font(.footnote).foregroundStyle(.secondary)
                Button("Check for updates now") {
                    SparkleUpdater.shared.checkForUpdates()
                    lastChecked = Date()
                    status = "Asked Sparkle to check the appcast."
                }
                .controlSize(.regular)
            }
            Section("How updates work") {
                Text("Murmur downloads signed updates from a public appcast hosted on GitHub Pages. "
                    + "The download is verified against an EdDSA public key embedded in the app bundle. "
                    + "No telemetry is sent during the check.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
