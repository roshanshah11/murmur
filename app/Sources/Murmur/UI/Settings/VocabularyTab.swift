// Phase 3: real Vocabulary editor.
//
// The tab is split into three bands:
//
//   1. Toolbar — add, remove, import, export, reset.
//   2. Editable list of vocabulary rows. We use `List` instead of `Table`
//      because TextField editing inside SwiftUI's `Table` on macOS 13 has
//      fiddly focus/commit semantics; a custom HStack-per-row keeps the
//      UX predictable.
//   3. Live preview — type a sample sentence and watch the cleaned output
//      update as vocab and profile change.
//
// All mutations route through `SettingsStore.shared`, which debounces and
// merges writes so concurrent edits from other tabs (e.g. General's
// History toggle) don't clobber each other.
import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - View model

@MainActor
final class VocabularyTabModel: ObservableObject {
    @Published var entries: [Vocabulary.Entry]
    @Published var sampleInput: String
    @Published private(set) var cleanedOutput: String = ""
    @Published var lastError: String?

    private let store: SettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: SettingsStore? = nil,
         defaultSample: String = "the api endpoint at chat gpt times out") {
        let resolvedStore = store ?? SettingsStore.shared
        self.store = resolvedStore
        self.entries = resolvedStore.config.vocabulary.entries
        self.sampleInput = defaultSample
        self.cleanedOutput = TextCleaner(
            vocabulary: resolvedStore.config.vocabulary,
            profile: resolvedStore.config.activeProfile
        ).clean(defaultSample)

        // Re-bind whenever the store's config changes from underneath us
        // (e.g. another window or import).
        resolvedStore.$config
            .sink { [weak self] cfg in
                guard let self else { return }
                if cfg.vocabulary.entries != self.entries {
                    self.entries = cfg.vocabulary.entries
                }
                self.recomputePreview()
            }
            .store(in: &cancellables)

        // Also re-run the preview whenever the user types in the sample
        // field — Combine handles this without an explicit onChange in
        // the view.
        $sampleInput
            .sink { [weak self] _ in
                self?.recomputePreview()
            }
            .store(in: &cancellables)
    }

    // MARK: Mutations

    /// Append a blank entry (or a seeded one when used by tests). Returns
    /// the new entry's ID so the UI can focus it.
    @discardableResult
    func addEntry(from: String = "", to: String = "") -> Vocabulary.Entry.ID {
        let entry = Vocabulary.Entry(from: from, to: to)
        entries.append(entry)
        persistEntries()
        return entry.id
    }

    func removeEntries(ids: Set<Vocabulary.Entry.ID>) {
        guard !ids.isEmpty else { return }
        entries.removeAll { ids.contains($0.id) }
        persistEntries()
    }

    /// Edit a row in place. Called from the SwiftUI bindings on each
    /// TextField change.
    func updateEntry(id: Vocabulary.Entry.ID, from: String, to: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].from = from
        entries[idx].to = to
        persistEntries()
    }

    func resetToDefaults() {
        entries = Config.defaultVocabulary().entries
        persistEntries()
    }

    // MARK: JSON I/O

    /// Accepts two shapes:
    ///   * Modern `Vocabulary` blob: `{"entries":[{"from":..,"to":..}]}`
    ///   * Legacy `customVocabulary` dictionary: `{"<from>":"<to>"}`
    /// Decoded entries fully replace the existing list — there is no
    /// "merge" UX in v1 because dedup ambiguity is more confusing than
    /// helpful.
    func importJSON(data: Data) throws {
        if let modern = try? JSONDecoder().decode(Vocabulary.self, from: data) {
            entries = modern.entries
        } else if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
            var vocab = Vocabulary()
            for key in legacy.keys.sorted() {
                vocab.upsert(from: key, to: legacy[key] ?? "")
            }
            entries = vocab.entries
        } else {
            struct ImportFormatError: LocalizedError {
                var errorDescription: String? {
                    "Couldn't parse JSON. Expected a Vocabulary or {from:to} dictionary."
                }
            }
            throw ImportFormatError()
        }
        persistEntries()
    }

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Vocabulary(entries))
    }

    // MARK: AppKit panel wrappers

    func runImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import vocabulary"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try importJSON(data: data)
            lastError = nil
        } catch {
            lastError = "Import failed: \(error.localizedDescription)"
        }
    }

    func runExportPanel() {
        let panel = NSSavePanel()
        panel.title = "Export vocabulary"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "murmur-vocabulary.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try exportJSON()
            try data.write(to: url, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: Internal

    private func persistEntries() {
        let snapshot = entries
        store.mutate { cfg in
            cfg.vocabulary = Vocabulary(snapshot)
        }
        recomputePreview()
    }

    private func recomputePreview() {
        let cleaner = TextCleaner(
            vocabulary: Vocabulary(entries),
            profile: store.config.activeProfile
        )
        cleanedOutput = cleaner.clean(sampleInput)
    }
}

// MARK: - View

struct VocabularyTab: View {
    @StateObject private var model = VocabularyTabModel()
    @State private var selection: Set<Vocabulary.Entry.ID> = []
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            toolbar
            entriesList
            previewPanel
            if let err = model.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vocabulary").font(.headline)
            Text("Replace mishearings with the real spelling. "
                + "Matching is case-insensitive and respects word boundaries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                let id = model.addEntry()
                selection = [id]
            } label: {
                Label("Add", systemImage: "plus")
            }

            Button(role: .destructive) {
                model.removeEntries(ids: selection)
                selection.removeAll()
            } label: {
                Label("Remove", systemImage: "minus")
            }
            .disabled(selection.isEmpty)

            Spacer()

            Button {
                model.runImportPanel()
            } label: {
                Label("Import…", systemImage: "square.and.arrow.down")
            }
            Button {
                model.runExportPanel()
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .disabled(model.entries.isEmpty)

            Button(role: .destructive) {
                confirmReset = true
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog(
                "Restore default vocabulary?",
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    model.resetToDefaults()
                    selection.removeAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your custom entries will be replaced with the shipped defaults.")
            }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var entriesList: some View {
        if model.entries.isEmpty {
            VStack(alignment: .center, spacing: 6) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No vocabulary yet")
                    .font(.subheadline)
                Text("Click + to add a misheard word and its replacement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.05))
            )
        } else {
            VStack(spacing: 0) {
                listHeaderRow
                Divider()
                List(selection: $selection) {
                    ForEach(model.entries) { entry in
                        VocabularyRow(
                            entry: entry,
                            onCommit: { from, to in
                                model.updateEntry(id: entry.id, from: from, to: to)
                            }
                        )
                        .tag(entry.id)
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
                .frame(minHeight: 160, idealHeight: 180)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var listHeaderRow: some View {
        HStack(spacing: 12) {
            Text("From").font(.caption).bold().foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("To").font(.caption).bold().foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.caption).bold()
                .foregroundStyle(.secondary)
            TextField("Sample input", text: $model.sampleInput)
                .textFieldStyle(.roundedBorder)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("→").foregroundStyle(.tertiary)
                Text(model.cleanedOutput.isEmpty ? "(empty)" : model.cleanedOutput)
                    .font(.body)
                    .foregroundStyle(model.cleanedOutput.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.06))
            )
        }
    }
}

// MARK: - Row

private struct VocabularyRow: View {
    let entry: Vocabulary.Entry
    let onCommit: (String, String) -> Void

    @State private var fromText: String
    @State private var toText: String

    init(entry: Vocabulary.Entry, onCommit: @escaping (String, String) -> Void) {
        self.entry = entry
        self.onCommit = onCommit
        self._fromText = State(initialValue: entry.from)
        self._toText = State(initialValue: entry.to)
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("misheard", text: $fromText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: fromText) { _ in onCommit(fromText, toText) }
            TextField("replacement", text: $toText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: toText) { _ in onCommit(fromText, toText) }
        }
        .padding(.vertical, 2)
    }
}
