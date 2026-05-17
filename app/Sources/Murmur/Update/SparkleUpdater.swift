// Sparkle 2 adapter. Wraps SPUStandardUpdaterController and exposes a
// minimal Murmur-facing API. Started at app launch.
import Foundation
import Sparkle

@MainActor
final class SparkleUpdater: NSObject {
    static let shared = SparkleUpdater()

    private let controller: SPUStandardUpdaterController

    private override init() {
        // startingUpdater:true means it immediately schedules its first check.
        // We pass nil delegates here; if we want to react to update events later,
        // attach an SPUUpdaterDelegate.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var lastUpdateCheckDate: Date? { controller.updater.lastUpdateCheckDate }
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
