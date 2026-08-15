import Combine
import Foundation
import OSLog

enum ScribeRefineAvailability: Equatable {
    case available
    case unsupportedIntel
    case insufficientMemory
}

enum ScribeRefineError: LocalizedError {
    case unavailable
    case modelNotDownloaded

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "Sotto Cleanup requires an Apple silicon Mac with at least 8 GB of memory.")
        case .modelNotDownloaded:
            return String(localized: "Sotto Cleanup is not downloaded.")
        }
    }
}

final class ScribeRefineService: ObservableObject {
    static let shared = ScribeRefineService()

    static let providerName = "Sotto Cleanup"
    static let modelName = "Sotto Cleanup"
    /// Sotto is trained as a raw completion model. The XPC engine applies its
    /// documented `### Input` / `### Output` completion template directly.
    static let systemPrompt = ""
    static let repositoryID = "juanquivilla/sotto-cleanup-lfm25-350m-mlx-5bit"
    static let pinnedRevision = "1b04172dbb5aeb2d9a585881592f6473e21e4889"
    static let minimumMemoryBytes: UInt64 = 8 * 1_024 * 1_024 * 1_024
    static var downloadSizeDescription: String {
        ByteCountFormatter.string(
            fromByteCount: ScribeRefineModelDownloader.totalBytes,
            countStyle: .file
        )
    }

    @Published private(set) var isDownloaded = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress = 0.0
    private(set) var downloadedBytes: Int64 = 0
    private(set) var totalDownloadBytes = ScribeRefineModelDownloader.totalBytes
    private(set) var isFinalizingDownload = false
    @Published private(set) var downloadError: String?

    let availability: ScribeRefineAvailability

    var isAvailableInModes: Bool {
        availability == .available && isDownloaded
    }

    var downloadedModelURL: URL? {
        isDownloaded ? snapshotURL : nil
    }

    var unavailableDescription: String? {
        switch availability {
        case .available:
            return nil
        case .unsupportedIntel:
            return String(localized: "Available on Apple silicon Macs with at least 8 GB of memory.")
        case .insufficientMemory:
            return String(localized: "Requires at least 8 GB of memory.")
        }
    }

    private let logger = Logger(
        subsystem: "com.prakashjoshipax.scribe",
        category: "ScribeRefineService"
    )
    private let modelRootDirectory: URL
    private let inferenceClient = ScribeRefineXPCClient()
    private var downloadTask: Task<Void, Never>?

    private init(
        architectureIsAppleSilicon: Bool = SystemArchitecture.isAppleSilicon,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) {
        if !architectureIsAppleSilicon {
            availability = .unsupportedIntel
        } else if physicalMemory < Self.minimumMemoryBytes {
            availability = .insufficientMemory
        } else {
            availability = .available
        }

        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        modelRootDirectory = appSupportDirectory
            .appendingPathComponent("com.prakashjoshipax.Scribe")
            .appendingPathComponent("ScribeRefine")

        refreshDownloadedState()
    }

    @MainActor
    func startDownload() {
        guard availability == .available, !isDownloaded, downloadTask == nil else {
            return
        }

        downloadTask = Task { [weak self] in
            await self?.downloadModel()
        }
    }

    @MainActor
    func cancelDownload() {
        downloadTask?.cancel()
    }

    @MainActor
    func deleteModel() async {
        cancelDownload()
        await inferenceClient.shutdown()

        do {
            if FileManager.default.fileExists(atPath: modelRootDirectory.path) {
                try FileManager.default.removeItem(at: modelRootDirectory)
            }
            downloadProgress = 0
            downloadedBytes = 0
            isFinalizingDownload = false
            downloadError = nil
            refreshDownloadedState()
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        } catch {
            downloadError = error.localizedDescription
            logger.error("Failed to delete Sotto Cleanup: \(error.localizedDescription, privacy: .public)")
        }
    }

    func enhance(transcript: String) async throws -> String {
        guard availability == .available else {
            throw ScribeRefineError.unavailable
        }
        guard isDownloaded, let snapshotURL else {
            throw ScribeRefineError.modelNotDownloaded
        }

        return try await inferenceClient.enhance(
            transcript: transcript,
            modelDirectory: snapshotURL,
            systemPrompt: Self.systemPrompt
        )
    }

    func unloadPreparedModelIfNeeded() async {
        await inferenceClient.shutdownPreparedModelIfNeeded()
    }

    func keepPreparedModelWarmForRecording() async {
        await inferenceClient.keepPreparedModelWarmForRecording()
    }

    func prepareForRecording() async {
        guard availability == .available, isDownloaded, let snapshotURL else {
            return
        }

        do {
            try await inferenceClient.prepare(
                modelDirectory: snapshotURL,
                systemPrompt: Self.systemPrompt
            )
        } catch is CancellationError {
        } catch {
            logger.error(
                "Background model preparation failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    @MainActor
    private func downloadModel() async {
        downloadProgress = 0
        downloadedBytes = 0
        totalDownloadBytes = ScribeRefineModelDownloader.totalBytes
        isFinalizingDownload = false
        downloadError = nil
        isDownloading = true

        defer {
            isDownloading = false
            isFinalizingDownload = false
            downloadTask = nil
        }

        #if arch(arm64)
            let downloader = ScribeRefineModelDownloader(
                repositoryID: Self.repositoryID,
                revision: Self.pinnedRevision,
                modelRootDirectory: modelRootDirectory
            )
            let progressTask = Task { @MainActor [weak self, downloader] in
                while !Task.isCancelled {
                    self?.applyDownloadProgress(downloader.progress)
                    try? await Task.sleep(for: .seconds(2))
                }
            }
            defer {
                progressTask.cancel()
            }

            do {
                let downloadOperation = Task.detached(priority: .utility) {
                    try await downloader.download()
                }
                defer {
                    downloadOperation.cancel()
                }

                try await withTaskCancellationHandler {
                    try await downloadOperation.value
                } onCancel: {
                    downloadOperation.cancel()
                }
                try Task.checkCancellation()
                applyDownloadProgress(downloader.progress)
                refreshDownloadedState()
                downloadProgress = isDownloaded ? 1 : 0
                NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
            } catch is CancellationError {
                downloadError = nil
            } catch {
                downloadError = error.localizedDescription
                logger.error("Failed to download Sotto Cleanup: \(error.localizedDescription, privacy: .public)")
            }
        #else
            downloadError = ScribeRefineError.unavailable.localizedDescription
        #endif
    }

    private var snapshotURL: URL? {
        #if arch(arm64)
            return ScribeRefineModelDownloader.snapshotDirectory(
                in: modelRootDirectory,
                repositoryID: Self.repositoryID,
                revision: Self.pinnedRevision
            )
        #else
            return nil
        #endif
    }

    private func refreshDownloadedState() {
        guard let snapshotURL else {
            isDownloaded = false
            return
        }

        isDownloaded = ScribeRefineModelDownloader.isSnapshotComplete(
            at: snapshotURL
        )
    }

    @MainActor
    private func applyDownloadProgress(
        _ progress: ScribeRefineDownloadProgress
    ) {
        downloadedBytes = progress.downloadedBytes
        totalDownloadBytes = progress.totalBytes
        isFinalizingDownload = progress.isFinalizing
        downloadProgress = progress.totalBytes > 0
            ? min(1, Double(progress.downloadedBytes) / Double(progress.totalBytes))
            : 0
    }
}
