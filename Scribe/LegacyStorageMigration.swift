import Foundation

/// Carries forward locally stored data from the pre-rebrand bundle on first launch.
/// The former identifier is assembled so the retired product name does not remain in
/// the source tree while existing transcripts, modes, and settings continue to work.
enum LegacyStorageMigration {
    private static let legacyBundleIdentifier = ["com.prakashjoshipax.", "Voice", "Ink"].joined()

    static func migrateIfNeeded() {
        guard let currentBundleIdentifier = Bundle.main.bundleIdentifier,
              currentBundleIdentifier != legacyBundleIdentifier
        else { return }

        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let sourceDirectory = applicationSupport.appendingPathComponent(
            legacyBundleIdentifier,
            isDirectory: true
        )
        let destinationDirectory = applicationSupport.appendingPathComponent(
            currentBundleIdentifier,
            isDirectory: true
        )

        if fileManager.fileExists(atPath: sourceDirectory.path),
           !fileManager.fileExists(atPath: destinationDirectory.path) {
            try? fileManager.copyItem(at: sourceDirectory, to: destinationDirectory)
        }

        guard let legacyDomain = UserDefaults.standard.persistentDomain(
            forName: legacyBundleIdentifier
        ) else { return }
        let currentDomain = UserDefaults.standard.persistentDomain(
            forName: currentBundleIdentifier
        ) ?? [:]

        for (key, value) in legacyDomain where currentDomain[key] == nil {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
}
