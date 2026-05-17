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
                Link("GitHub", destination: URL(string: "https://github.com/roshanshah11/murmur")!)
                Link("Docs", destination: URL(string: "https://roshanshah11.github.io/murmur/")!)
                Link("Sponsor", destination: URL(string: "https://github.com/sponsors/roshanshah11")!)
            }
            Spacer()
            Text("Made with ♥ for people who like their voice to stay on their Mac.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
