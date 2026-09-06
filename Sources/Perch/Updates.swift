import AppKit
import Combine
import Sparkle
import SwiftUI
import PerchCore

/// Sparkle owns scheduling and its native download/install UI. No custom poller.
@MainActor final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheck = false
    @Published var automaticChecks = false {
        didSet { if controller?.updater.automaticallyChecksForUpdates != automaticChecks { controller?.updater.automaticallyChecksForUpdates = automaticChecks } }
    }
    private var controller: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []
    private weak var store: AppStore?
    private(set) var installationPrepared = false

    init(store: AppStore) {
        self.store = store
        super.init()
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        observations = [
            controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
                DispatchQueue.main.async { self?.canCheck = change.newValue ?? false }
            },
            controller.updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] _, change in
                DispatchQueue.main.async { self?.automaticChecks = change.newValue ?? false }
            }
        ]
        controller.startUpdater()
    }
    func check() { controller?.checkForUpdates(nil) }

    // This is consulted immediately before Sparkle installs, and returning false
    // aborts that installation. A user can finish an editor then check again.
    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
        do {
            guard let store else { return false }
            try store.prepareForUpdate()
            installationPrepared = true
            return true
        } catch {
            let alert = NSAlert(); alert.messageText = "Perch is keeping your work safe"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Keep Perch open"); alert.runModal()
            return false
        }
    }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) { installationPrepared = false }
}

extension AppStore {
    @discardableResult func prepareForUpdate() throws -> URL {
        guard !storageLocked else { throw UpdateSafetyError.protectedData }
        guard !capturePresented, openDialogCount == 0, canDismissPanel?() != false else { throw UpdateSafetyError.editorOpen }
        guard flush() else { throw UpdateSafetyError.saveFailed(error ?? "Check disk space and folder access.") }
        return try UpdateBackup.create(dataURL: dataURL)
    }
}

enum UpdateSafetyError: LocalizedError {
    case editorOpen, protectedData, saveFailed(String)
    var errorDescription: String? {
        switch self {
        case .editorOpen: "Save or cancel the open editor or file dialog, then check for updates again."
        case .protectedData: "Resolve the local data error before installing an update. Your current data has been left untouched."
        case .saveFailed(let message): "Your latest changes couldn’t be saved. \(message)"
        }
    }
}

struct UpdateSettings: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Updates").font(.headline)
            Button("Check for updates…") { updates.check() }.disabled(!updates.canCheck)
            Toggle("Automatically check for updates", isOn: $updates.automaticChecks)
            Text("Choose when to install. Perch saves your work and keeps a local data backup before updating.")
                .font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
