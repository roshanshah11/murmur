// Phase 5: opt-in History viewer.
//
// The window is decoupled from AppState because the menubar wiring may open
// it before or after the AppState's HistoryStore is constructed. To avoid
// two writers on the same JSONL file we keep a single `HistoryStore` per
// process: `HistoryWindowController.shared.store` is set once at launch in
// main.swift, and SwiftUI views read from it via the SharedHistoryStore
// holder.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Window controller

final class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()

    /// Set once at process launch (main.swift). All History UI reads through
    /// this single instance so the JSONL file has exactly one writer.
    static var store: HistoryStore?

    /// PasteboardInserter used by the "Re-paste" row action. Like `store`,
    /// set once at launch so the History window doesn't construct a second
    /// inserter (or worse, fail to honor user paste settings).
    static var inserter: PasteboardInserter?

    private convenience init() {
        let host = NSHostingController(rootView: HistoryRoot())
        let window = NSWindow(contentViewController: host)
        window.title = "Murmur History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 520))
        window.setFrameAutosaveName("MurmurHistory")
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        // Nudge SwiftUI to refresh the table contents on each open.
        NotificationCenter.default.post(name: .murmurHistoryRefreshRequested, object: nil)
    }
}

extension Notification.Name {
    static let murmurHistoryRefreshRequested = Notification.Name("murmur.history.refresh")
}

// MARK: - Root SwiftUI view

struct HistoryRoot: View {
    @State private var entries: [HistoryEntry] = []
    @State private var query: String = ""
    @State private var selection: HistoryEntry.ID?
    @State private var confirmClear: Bool = false
    @State private var statusMessage: String?

    private var filtered: [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        let needle = trimmed.lowercased()
        return entries.filter { entry in
            entry.cleaned.lowercased().contains(needle)
                || entry.targetApp.lowercased().contains(needle)
                || entry.raw.lowercased().contains(needle)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            historyTable
            footer
        }
        .frame(minWidth: 560, minHeight: 380)
        .searchable(text: $query, placement: .toolbar, prompt: "Search transcripts")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    confirmClear = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(entries.isEmpty)

                Button(action: exportMarkdown) {
                    Label("Export as Markdown…", systemImage: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
            }
        }
        .confirmationDialog(
            "Clear all history?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                HistoryWindowController.store?.clear()
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every transcript stored on disk. Cannot be undone.")
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .murmurHistoryRefreshRequested)) { _ in
            reload()
        }
    }

    @ViewBuilder
    private var historyTable: some View {
        if entries.isEmpty {
            emptyState
        } else {
            Table(filtered, selection: $selection) {
                TableColumn("Time") { entry in
                    Text(shortTimestamp(entry.ts))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(min: 110, ideal: 130, max: 160)

                TableColumn("App") { entry in
                    HStack(spacing: 4) {
                        if entry.favorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                        Text(entry.targetApp).lineLimit(1)
                    }
                }
                .width(min: 90, ideal: 110, max: 160)

                TableColumn("Duration") { entry in
                    Text(formatDuration(entry.durationMs))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 80, max: 100)

                TableColumn("Chars") { entry in
                    Text("\(entry.cleaned.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .width(min: 50, ideal: 60, max: 80)

                TableColumn("Transcript") { entry in
                    Text(entry.cleaned)
                        .lineLimit(2)
                        .help(entry.cleaned)
                }
            }
            .contextMenu(forSelectionType: HistoryEntry.ID.self) { ids in
                if let id = ids.first, let entry = entries.first(where: { $0.id == id }) {
                    contextMenu(for: entry)
                }
            } primaryAction: { ids in
                if let id = ids.first, let entry = entries.first(where: { $0.id == id }) {
                    copyToClipboard(entry)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No transcripts yet")
                .font(.headline)
            Text("Dictations you make while history is enabled will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("\(entries.count) entries · stored at ~/Library/Application Support/Murmur/history.jsonl")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Refresh", action: reload)
                .buttonStyle(.borderless)
                .font(.footnote)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Row actions

    @ViewBuilder
    private func contextMenu(for entry: HistoryEntry) -> some View {
        Button {
            copyToClipboard(entry)
        } label: {
            Label("Copy text", systemImage: "doc.on.doc")
        }
        Button {
            rePaste(entry)
        } label: {
            Label("Re-paste", systemImage: "arrow.uturn.left")
        }
        Button {
            toggleFavorite(entry)
        } label: {
            Label(
                entry.favorite ? "Unfavorite" : "Favorite",
                systemImage: entry.favorite ? "star.slash" : "star"
            )
        }
        Divider()
        Button(role: .destructive) {
            deleteRow(entry)
        } label: {
            Label("Delete row", systemImage: "trash")
        }
    }

    private func copyToClipboard(_ entry: HistoryEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.cleaned, forType: .string)
        flashStatus("Copied \(entry.cleaned.count) characters to clipboard.")
    }

    private func rePaste(_ entry: HistoryEntry) {
        guard let inserter = HistoryWindowController.inserter else {
            flashStatus("Re-paste unavailable (no inserter wired).")
            return
        }
        // Focus the previous frontmost app before posting Cmd-V so paste
        // lands wherever the user was last typing, not in the History window.
        let result = inserter.paste(entry.cleaned)
        switch result {
        case .pasted(let target):
            flashStatus("Pasted into \(target.name).")
        case .copiedOnly(let reason):
            flashStatus("Copied to clipboard — \(reason).")
        }
    }

    private func toggleFavorite(_ entry: HistoryEntry) {
        HistoryWindowController.store?.setFavorite(id: entry.id, !entry.favorite)
        reload()
    }

    private func deleteRow(_ entry: HistoryEntry) {
        HistoryWindowController.store?.delete(id: entry.id)
        reload()
    }

    // MARK: - Export

    private func exportMarkdown() {
        guard !entries.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = defaultExportFilename()
        panel.canCreateDirectories = true
        panel.title = "Export Murmur History"
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        let body = HistoryRoot.markdownReport(for: entries)
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            flashStatus("Exported \(entries.count) entries.")
        } catch {
            flashStatus("Export failed: \(error.localizedDescription)")
        }
    }

    private func defaultExportFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        return "murmur-history-\(df.string(from: Date())).md"
    }

    /// Internal-static so HistoryWindowExportTests (if added later) can
    /// exercise the formatter without standing up a window.
    static func markdownReport(for entries: [HistoryEntry]) -> String {
        var out = "# Murmur history\n\nExported \(ISO8601DateFormatter().string(from: Date()))\n\n"
        out += "_\(entries.count) entries._\n\n---\n\n"
        for entry in entries {
            let star = entry.favorite ? " ⭐" : ""
            out += "### \(entry.ts) — \(entry.targetApp)\(star)\n\n"
            out += "- Duration: \(entry.durationMs) ms\n"
            out += "- Characters: \(entry.cleaned.count)\n"
            out += "- Result: \(entry.result)\n\n"
            out += "> \(entry.cleaned.replacingOccurrences(of: "\n", with: "\n> "))\n\n"
            out += "---\n\n"
        }
        return out
    }

    // MARK: - Helpers

    private func reload() {
        entries = HistoryWindowController.store?.loadAll() ?? []
    }

    private func flashStatus(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if statusMessage == message { statusMessage = nil }
        }
    }

    private func shortTimestamp(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM d HH:mm"
        return display.string(from: date)
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms) ms" }
        let seconds = Double(ms) / 1000
        return String(format: "%.1fs", seconds)
    }
}
