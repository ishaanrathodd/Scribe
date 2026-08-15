import AppKit
import SwiftUI

// MARK: - Local Model Card View
struct WhisperModelCardView: View {
    let model: WhisperModel
    let isDownloaded: Bool
    let downloadProgress: [String: Double]
    let modelURL: URL?
    let isWarming: Bool

    // Actions
    var deleteAction: () -> Void
    var downloadAction: () -> Void
    private var isDownloading: Bool {
        downloadProgress.keys.contains(model.name + "_main") || downloadProgress.keys.contains(model.name + "_coreml")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Main Content
            VStack(alignment: .leading, spacing: 6) {
                headerSection
                metadataSection
                descriptionSection
                progressSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action Controls
            actionSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.labelColor))

            Spacer()
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 12) {
            // Language
            Label(model.language, systemImage: "globe")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)

            // Size
            Label(model.size, systemImage: "internaldrive")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)

        }
        .lineLimit(1)
    }

    private var descriptionSection: some View {
        Text(model.description)
            .font(.system(size: 11))
            .foregroundColor(Color(.secondaryLabelColor))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private var progressSection: some View {
        Group {
            if isDownloading || isWarming {
                DownloadProgressView(
                    modelName: model.name,
                    downloadProgress: downloadProgress,
                    isOptimizing: isWarming && !isDownloading
                )
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            if !isDownloaded {
                Button(action: downloadAction) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey(isDownloading ? "Downloading..." : "Download"))
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.Accent.primary)
                            .shadow(color: AppTheme.Accent.shadow, radius: 2, x: 0, y: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDownloading)
            }

            if isDownloaded {
                Menu {
                    Button(action: deleteAction) {
                        Label("Delete Model", systemImage: "trash")
                    }

                    Button {
                        if let modelURL = modelURL {
                            NSWorkspace.shared.selectFile(modelURL.path, inFileViewerRootedAtPath: "")
                        }
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 32, height: 32)

                modelStatusPill("Downloaded", systemImage: "checkmark.circle")
            }
        }
    }
}

// MARK: - Imported Local Model (minimal UI)
struct ImportedWhisperModelCardView: View {
    let model: ImportedWhisperModel
    let isDownloaded: Bool
    let modelURL: URL?

    var deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.labelColor))
                    Spacer()
                }

                Text("Imported local model")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if isDownloaded {
                    Menu {
                        Button(action: deleteAction) {
                            Label("Delete Model", systemImage: "trash")
                        }
                        Button {
                            if let modelURL = modelURL {
                                NSWorkspace.shared.selectFile(modelURL.path, inFileViewerRootedAtPath: "")
                            }
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 32, height: 32)

                    modelStatusPill("Imported", systemImage: "checkmark.circle")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Helper Views and Functions

func progressDotsWithNumber(value: Double) -> some View {
    HStack(spacing: 4) {
        progressDots(value: value)
        Text(String(format: "%.1f", value))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Color(.secondaryLabelColor))
    }
}

func progressDots(value: Double) -> some View {
    HStack(spacing: 2) {
        ForEach(0..<5) { index in
            Circle()
                .fill(index < Int(value / 2) ? performanceColor(value: value / 10) : Color(.quaternaryLabelColor))
                .frame(width: 6, height: 6)
        }
    }
}

func performanceColor(value: Double) -> Color {
    switch value {
    case 0.8...1.0: return AppTheme.Status.positive
    case 0.6..<0.8: return AppTheme.Data.yellow
    case 0.4..<0.6: return AppTheme.Status.warningStrong
    default: return AppTheme.Status.error
    }
}

func modelStatusPill(_ text: LocalizedStringKey, systemImage: String) -> some View {
    HStack(spacing: 4) {
        Text(text)
        Image(systemName: systemImage)
    }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(Color(.secondaryLabelColor))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.Surface.card)
        .clipShape(Capsule())
}
