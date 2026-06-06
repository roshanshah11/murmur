import Foundation

/// Which speech-to-text backend the dictation pipeline uses. Persisted in Config.
enum TranscriptionEngineKind: String, Codable, CaseIterable, Equatable {
    case parakeet      // NVIDIA Parakeet via FluidAudio (Core ML / Apple Neural Engine)
    case whisperCpp    // whisper.cpp subprocess

    /// Hardware-appropriate default. Parakeet runs on the Apple Neural Engine
    /// (fast on Apple Silicon); on Intel Macs Core ML falls back to CPU/GPU and
    /// is slow, so whisper.cpp is the better default there.
    static var deviceDefault: TranscriptionEngineKind {
        isAppleSilicon ? .parakeet : .whisperCpp
    }

    /// Runtime check (works for universal binaries running natively). Returns
    /// true on Apple Silicon. Uses the `hw.optional.arm64` sysctl.
    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }
}
