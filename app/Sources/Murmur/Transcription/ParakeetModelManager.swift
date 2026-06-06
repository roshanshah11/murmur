import Foundation
import FluidAudio

/// Settings-facing model state for the Parakeet (FluidAudio, v3) engine.
///
/// Mirrors the shape of the GGML `ModelManager` so the Models tab can present
/// Parakeet with the same install / download / progress affordances. FluidAudio
/// owns the on-disk cache (`~/Library/Application Support/FluidAudio/Models/`),
/// so this is a thin adapter rather than a downloader of its own.
@MainActor
final class ParakeetModelManager: ObservableObject {
    @Published private(set) var isInstalled: Bool = false
    /// Non-nil (0...1) while a download is in flight; nil otherwise.
    @Published private(set) var progress: Double?
    @Published private(set) var lastError: String?

    /// Approximate on-disk size of the v3 model at the default int8 encoder
    /// precision. Surfaced in the UI alongside the GGML sizes.
    static let approxSizeMB = 470

    init() { refreshInstalled() }

    private var modelsDirectory: URL { MLModelConfigurationUtils.defaultModelsDirectory() }

    func refreshInstalled() {
        isInstalled = AsrModels.modelsExist(at: modelsDirectory, version: .v3)
    }

    /// User-initiated download from Settings. Surfaces progress both locally
    /// (`progress`) and on the notch overlay via the same notification bridge
    /// the GGML downloads use, so the on-screen behavior is identical.
    func download() async {
        guard progress == nil else { return }
        lastError = nil
        progress = 0
        NotificationCenter.default.post(name: .murmurModelDownloadProgress, object: 0.0)
        do {
            _ = try await AsrModels.download(to: nil, version: .v3) { p in
                let fraction = p.fractionCompleted
                Task { @MainActor in
                    self.progress = fraction
                    NotificationCenter.default.post(name: .murmurModelDownloadProgress, object: fraction)
                }
            }
            progress = nil
            refreshInstalled()
            NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: nil)
        } catch {
            progress = nil
            lastError = "Parakeet model download failed: \(error)"
            NotificationCenter.default.post(name: .murmurModelDownloadFinished, object: nil)
        }
    }
}
