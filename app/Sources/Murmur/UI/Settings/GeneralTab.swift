// Phase 5: real content for the General tab.
//
// Source of truth: the on-disk config.json file. We load it on appear and
// rewrite on every toggle change so the menubar's enable-state check
// (Config.loadOrCreateDefault().historyEnabled) sees the new value
// immediately. The AppState's in-memory copy stays captured at launch —
// that's deliberate for v1; a full hot-reload of the running pipeline
// lands in a later phase.
import SwiftUI

struct GeneralTab: View {
    @State private var historyEnabled: Bool = false
    @State private var hasEntriesOnDisk: Bool = false
    @State private var saveError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Enable dictation history", isOn: $historyEnabled)
                    .onChange(of: historyEnabled) { newValue in
                        persistHistoryEnabled(newValue)
                    }

                Text("When on, Murmur keeps a local record of past transcriptions at "
                     + "~/Library/Application Support/Murmur/history.jsonl. Nothing leaves your machine.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Open History…") {
                        HistoryWindowController.shared.showWindow(nil)
                    }
                    .disabled(!historyEnabled)

                    Button("Clear history now", role: .destructive) {
                        HistoryWindowController.store?.clear()
                        refreshHasEntries()
                    }
                    .disabled(!historyEnabled || !hasEntriesOnDisk)

                    Spacer()
                }
                .padding(.top, 4)

                if let saveError {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("History")
            } footer: {
                Text("Note: history is OFF by default. Toggling here takes effect immediately "
                     + "for new dictations; clearing removes the on-disk file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear(perform: loadFromDisk)
    }

    private func loadFromDisk() {
        let cfg = Config.loadOrCreateDefault()
        historyEnabled = cfg.historyEnabled
        refreshHasEntries()
    }

    private func refreshHasEntries() {
        // Use the shared store if main.swift wired it; otherwise inspect the
        // file directly so the button state stays accurate even before
        // AppState constructs the store on first launch.
        if let store = HistoryWindowController.store {
            hasEntriesOnDisk = store.hasEntries()
        } else {
            hasEntriesOnDisk = FileManager.default.fileExists(atPath: AppPaths.historyFile.path)
        }
    }

    private func persistHistoryEnabled(_ newValue: Bool) {
        do {
            var cfg = Config.loadOrCreateDefault()
            cfg.historyEnabled = newValue
            try cfg.save()
            saveError = nil
            // Refresh disk-entry state — flipping the toggle doesn't itself
            // delete entries, but the user may have toggled while having an
            // existing file from a previous opt-in.
            refreshHasEntries()
            NotificationCenter.default.post(name: .murmurHistoryToggleChanged, object: newValue)
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

extension Notification.Name {
    /// Posted when the user flips the History toggle in General settings.
    /// main.swift listens so the menubar's "History…" item re-evaluates its
    /// enable-state on the next rebuild.
    static let murmurHistoryToggleChanged = Notification.Name("murmur.history.toggle.changed")
}
