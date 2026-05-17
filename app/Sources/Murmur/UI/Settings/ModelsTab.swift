// Models tab: picks a Whisper model + a transcription language.
//
// Download progress is announced via NotificationCenter so the AppDelegate
// can mirror it onto MurmurState.downloadingModel (which lights up the
// notch overlay). Selecting a model rewrites Config.modelPath on disk;
// the running pipeline picks it up on the next dictation invocation
// after the next app launch (Phase 4 ships persistence only — live
// hot-swap of an in-flight WhisperRunner lands in a later phase).
import SwiftUI

extension Notification.Name {
    static let murmurModelDownloadProgress = Notification.Name("murmur.model.download.progress")
    static let murmurModelDownloadFinished = Notification.Name("murmur.model.download.finished")
}

struct ModelsTab: View {
    @StateObject private var manager = ModelManager()
    @AppStorage("settings.selectedModelName") private var selectedModelName: String = "ggml-base.en"
    @AppStorage("settings.selectedLanguage")  private var selectedLanguage: String = "auto"
    @State private var inFlightError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Whisper Models").font(.headline)
                Text("Pick a model. Larger means more accurate, slower, and more disk.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if manager.manifest.entries.isEmpty {
                Text("Bundled manifest unavailable.")
                    .font(.footnote).foregroundStyle(.red)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.manifest.entries) { entry in
                            ModelRow(
                                entry: entry,
                                isInstalled: manager.isInstalled(entry.name),
                                isSelected: selectedModelName == entry.name,
                                progress: manager.downloads[entry.name],
                                onDownload: { Task { await downloadAction(entry) } },
                                onDelete: { deleteAction(entry) },
                                onSelect: { selectAction(entry) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 220)
            }

            Divider()

            HStack {
                Text("Language").font(.subheadline)
                Picker("", selection: $selectedLanguage) {
                    ForEach(Self.languages, id: \.code) { item in
                        Text(item.label).tag(item.code)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                .onChange(of: selectedLanguage) { new in
                    persistLanguage(new)
                }
                Spacer()
            }

            if let error = inFlightError ?? manager.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }

            Text("Models live in ~/Library/Application Support/Murmur/Models/ — \(manager.installed.count) installed.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .onChange(of: manager.downloads) { new in
            // Surface the max progress across simultaneous downloads. The
            // notch overlay only has room for one bar; if a user kicks off
            // two downloads at once, showing the closer-to-done one keeps
            // the % monotonically rising on screen.
            if let maxProgress = new.values.max() {
                NotificationCenter.default.post(
                    name: .murmurModelDownloadProgress,
                    object: maxProgress
                )
            } else {
                NotificationCenter.default.post(
                    name: .murmurModelDownloadFinished,
                    object: nil
                )
            }
        }
    }

    // MARK: - Actions

    private func downloadAction(_ entry: ModelManifest.Entry) async {
        inFlightError = nil
        do {
            try await manager.download(entry)
            NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: entry.name)
        } catch {
            inFlightError = "Download failed: \(error)"
            NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: entry.name)
        }
    }

    private func deleteAction(_ entry: ModelManifest.Entry) {
        do {
            try manager.delete(entry)
            if selectedModelName == entry.name {
                // Fall back to the seed default; next launch will pick it up.
                selectedModelName = "ggml-base.en"
                persistSelection(name: "ggml-base.en")
            }
        } catch {
            inFlightError = "Remove failed: \(error)"
        }
    }

    private func selectAction(_ entry: ModelManifest.Entry) {
        selectedModelName = entry.name
        persistSelection(name: entry.name)
    }

    /// Rewrites `Config.modelPath` on disk. Reads the existing config (so we
    /// don't clobber unrelated fields), mutates the relevant field, writes
    /// atomically. Errors are surfaced to the UI but never crash.
    private func persistSelection(name: String) {
        do {
            var cfg = Config.loadOrCreateDefault()
            let path = AppPaths.modelsDirectory
                .appendingPathComponent("\(name).bin").path
            cfg.modelPath = path
            try cfg.save()
        } catch {
            inFlightError = "Couldn't save selection: \(error)"
        }
    }

    private func persistLanguage(_ code: String) {
        do {
            var cfg = Config.loadOrCreateDefault()
            // Whisper convention: "auto" maps to empty string for auto-detect.
            cfg.language = (code == "auto") ? "" : code
            try cfg.save()
        } catch {
            inFlightError = "Couldn't save language: \(error)"
        }
    }

    // Whisper-supported languages. Curated short list — keeps the picker
    // usable without a 99-item dropdown. Auto-detect is the default.
    private static let languages: [(code: String, label: String)] = [
        ("auto", "Auto-detect"),
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ko", "Korean"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("hi", "Hindi")
    ]
}

private struct ModelRow: View {
    let entry: ModelManifest.Entry
    let isInstalled: Bool
    let isSelected: Bool
    let progress: Double?
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName).font(.body).bold()
                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    if isSelected {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.18))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())
                    }
                }
                Text(entry.notes).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label("\(entry.sizeMB) MB", systemImage: "internaldrive")
                    Label(entry.language == "en" ? "English" : "Multilingual", systemImage: "globe")
                    if !entry.recommendedFor.isEmpty {
                        Label(entry.recommendedFor.joined(separator: ", "), systemImage: "cpu")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            controls
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear)
        .cornerRadius(8)
    }

    @ViewBuilder
    private var controls: some View {
        if let p = progress {
            VStack(alignment: .trailing, spacing: 2) {
                ProgressView(value: p).frame(width: 110)
                Text("\(Int((p * 100).rounded()))%")
                    .font(.caption2).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else if isInstalled {
            HStack(spacing: 6) {
                if !isSelected {
                    Button("Use", action: onSelect).buttonStyle(.bordered)
                }
                Button("Remove", role: .destructive, action: onDelete)
                    .buttonStyle(.borderless)
            }
        } else {
            Button("Download", action: onDownload).buttonStyle(.bordered)
        }
    }
}
