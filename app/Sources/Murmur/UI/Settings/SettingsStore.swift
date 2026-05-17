// Shared, debounced writer for Config. Phase 3 introduces it so the
// Vocabulary and Prompts tabs don't each invent their own load → mutate →
// save dance. Other tabs (General, Models) keep their inline patterns for
// now — migrating them is intentionally out of scope.
//
// Design notes:
//
//   1. Mutations are recorded as a queue of `(inout Config) -> Void`
//      closures, not snapshot-and-write. On flush we re-read disk, replay
//      the queue, then write. This avoids clobbering edits another tab
//      may have committed in the meantime (e.g. user flips History in
//      General while editing vocab here — both must persist).
//
//   2. The `@Published var config` mirror is updated synchronously so
//      SwiftUI bindings stay responsive; the heavy disk write trails on
//      a 250 ms debounce.
//
//   3. URL is injectable for tests. Production callers use the
//      `SettingsStore.shared` singleton wired to `AppPaths.configFile`.
//
//   4. After a successful write we post `.murmurConfigUpdated` so other
//      windows (notch overlay, menubar text) can refresh on demand.
import Combine
import Foundation

extension Notification.Name {
    /// Posted by `SettingsStore` after the debounced disk write completes.
    /// Listeners use this to refresh any in-memory copies of Config.
    static let murmurConfigUpdated = Notification.Name("murmur.config.updated")
}

@MainActor
final class SettingsStore: ObservableObject {
    /// Singleton wired to the real on-disk config. Tests construct their
    /// own instances pointing at a temp URL.
    static let shared = SettingsStore()

    @Published private(set) var config: Config

    /// Test hook — invoked after every successful disk write. Production
    /// callers leave this nil; tests use it to count saves and assert
    /// debounce coalescing.
    var onSave: (() -> Void)?

    private let configURL: URL
    private let debounceMs: Int
    private var pending: [(inout Config) -> Void] = []
    private let flushSubject = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []
    private let writeQueue = DispatchQueue(label: "murmur.settings.write", qos: .utility)

    init(configURL: URL = AppPaths.configFile, debounceMs: Int = 250) {
        self.configURL = configURL
        self.debounceMs = debounceMs
        // Load once — subsequent reads only happen on flush so we can
        // merge against other tabs' writes.
        self.config = Self.load(from: configURL)

        flushSubject
            .debounce(for: .milliseconds(debounceMs), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.flush()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Mutate a single Config field. The change is reflected in `config`
    /// immediately (so SwiftUI re-renders) and queued for a debounced
    /// disk write. Multiple updates within the debounce window collapse
    /// into a single save.
    func update<T>(_ keyPath: WritableKeyPath<Config, T>, to value: T) {
        config[keyPath: keyPath] = value
        pending.append { cfg in
            cfg[keyPath: keyPath] = value
        }
        flushSubject.send()
    }

    /// Apply an arbitrary mutation. Used for batch edits (e.g. JSON
    /// import) where multiple Config fields move at once.
    func mutate(_ block: @escaping (inout Config) -> Void) {
        block(&config)
        pending.append(block)
        flushSubject.send()
    }

    /// Force an immediate flush. Used by tests and by `close` paths
    /// where waiting on the debounce would be unsafe.
    func flushNow() {
        flush()
    }

    // MARK: - Internal

    private func flush() {
        guard !pending.isEmpty else { return }
        let mutations = pending
        pending.removeAll()

        // Re-read disk so we merge against any inline writes from other
        // tabs (GeneralTab.persistHistoryEnabled, ModelsTab.persistSelection,
        // etc.). The in-memory mirror is updated synchronously above so
        // the UI never lags — this read only feeds the merged write.
        var merged = Self.load(from: configURL)
        for mut in mutations {
            mut(&merged)
        }

        do {
            try write(merged, to: configURL)
            // Replace the published mirror with the merged result so
            // any inline writes other tabs made during the debounce
            // window become visible here too.
            self.config = merged
            onSave?()
            NotificationCenter.default.post(name: .murmurConfigUpdated, object: nil)
        } catch {
            Log.error("SettingsStore flush failed: \(error)")
        }
    }

    private static func load(from url: URL) -> Config {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return Config.defaultConfig()
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            Log.error("SettingsStore couldn't load \(url.path): \(error)")
            return Config.defaultConfig()
        }
    }

    private func write(_ cfg: Config, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cfg)
        try data.write(to: url, options: .atomic)
        Log.event(state: "config_saved", fields: ["path": url.path, "via": "SettingsStore"])
    }
}
