import AppKit
import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text("Murmur").font(.largeTitle).bold()
                    Text("Local-first voice typing for the Mac")
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Divider()
            HStack(spacing: 16) {
                aboutLink("GitHub", "https://github.com/roshanshah11/murmur")
                aboutLink("Docs", "https://roshanshah11.github.io/murmur/")
                aboutLink("Sponsor", "https://github.com/sponsors/roshanshah11")
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Setup wizard").font(.subheadline)
                    Text("Re-run the first-launch onboarding flow.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run setup again") {
                    OnboardingWindowController.shared.showWindow(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Text("Made with ♥ for people who like their voice to stay on their Mac.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A Link to a known-valid URL literal without force-unwrapping (keeps the
    /// force_unwrapping rule happy across SwiftLint versions). The string is a
    /// compile-time constant, so the Link always renders.
    @ViewBuilder
    private func aboutLink(_ title: String, _ urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(title, destination: url)
        }
    }
}
