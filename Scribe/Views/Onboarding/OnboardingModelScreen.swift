import SwiftUI

/// Sets up the required transcription model, with optional on-device cleanup.
struct OnboardingModelScreen: View {
    let contentMaxWidth: CGFloat
    let localModel: FluidAudioModel?
    let isLocalDownloaded: Bool
    let isLocalDownloading: Bool
    let localDownloadStatus: FluidAudioDownloadStatus?
    let isSetupReady: Bool
    let onDownload: (FluidAudioModel) -> Void
    let onBack: () -> Void
    let onContinue: () -> Void

    @ObservedObject private var cleanupService = ScribeRefineService.shared
    var body: some View {
        OnboardingStepScreen(
            systemImage: "waveform",
            title: "Prepare Scribe for private dictation",
            subtitle: "Download the required transcription model. Add optional on-device cleanup whenever you want fully private refinement.",
            contentMaxWidth: contentMaxWidth
        ) {
            VStack(spacing: 0) {
                modelRow(
                    icon: "waveform",
                    title: "On-device transcription",
                    description: "Preparing a fast, private transcription model for your Mac.",
                    isDownloaded: isLocalDownloaded,
                    isDownloading: isLocalDownloading,
                    progress: localDownloadStatus?.fractionCompleted,
                    progressMessage: localDownloadStatus?.message,
                    error: nil,
                    isRequired: true,
                    onDownload: localModel.map { model in { onDownload(model) } }
                )
                Divider().padding(.leading, 56)
                modelRow(
                    icon: "sparkles",
                    title: "On-device cleanup",
                    description: "Preparing Sotto Cleanup to refine dictated text on your Mac.",
                    isDownloaded: cleanupService.isDownloaded,
                    isDownloading: cleanupService.isDownloading,
                    progress: cleanupService.downloadProgress,
                    progressMessage: cleanupService.isFinalizingDownload ? "Finalizing download…" : "Downloading…",
                    error: cleanupService.downloadError ?? cleanupService.unavailableDescription,
                    isRequired: false,
                    onDownload: { cleanupService.startDownload() }
                )
            }
            .background(OnboardingCardSurface())
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Back",
                primaryTitle: "Continue",
                isPrimaryEnabled: isSetupReady,
                onLeading: onBack,
                onPrimary: onContinue
            )
        }
    }

    @ViewBuilder
    private func modelRow(
        icon: String,
        title: String,
        description: String,
        isDownloaded: Bool,
        isDownloading: Bool,
        progress: Double?,
        progressMessage: String?,
        error: String?,
        isRequired: Bool,
        onDownload: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
                if isDownloaded {
                    EmptyView()
                } else if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red).padding(.top, 2)
                } else if isDownloading {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(progressMessage ?? "Downloading…")
                            Spacer()
                            if let progress { Text(progress, format: .percent.precision(.fractionLength(0))) }
                        }
                        .font(.footnote).foregroundStyle(.secondary)
                        if let progress { ProgressView(value: progress) } else { ProgressView() }
                    }
                    .padding(.top, 4)
                } else {
                    Text(isRequired
                        ? "Required to continue."
                        : "Optional — download when you're ready.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 12)

            if isDownloaded {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.green)
            } else if !isDownloading, let onDownload {
                Button("Download", action: onDownload)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
            }
        }
        .padding(18)
    }
}
