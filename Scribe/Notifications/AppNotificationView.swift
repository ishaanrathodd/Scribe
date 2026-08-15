import SwiftUI

struct AppNotificationView: View {
    let title: String
    let type: NotificationType
    let duration: TimeInterval
    let onClose: () -> Void
    let onTap: (() -> Void)?
    var actionButton: (label: String, action: () -> Void)? = nil

    enum NotificationType {
        case error
        case warning
        case info
        case success

        var iconName: String {
            switch self {
            case .error: return "xmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .error: return AppTheme.Status.error
            case .warning: return AppTheme.Status.warning
            case .info: return AppTheme.Status.info
            case .success: return AppTheme.Status.success
            }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(type.iconColor)
                .frame(width: 30, height: 30)
                .background(type.iconColor.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Text.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if let actionButton {
                Button(action: {
                    actionButton.action()
                    onClose()
                }) {
                    Text(actionButton.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Text.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                }
                .buttonStyle(.plain)
                .background {
                    Capsule(style: .continuous)
                        .fill(AppTheme.Surface.controlActive.opacity(0.84))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(AppTheme.Border.subtle, lineWidth: 0.8)
                        }
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Text.secondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.Surface.controlActive.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 260, maxWidth: 720, minHeight: 52)
        .background(
            Capsule(style: .continuous)
                .fill(.clear)
                .background(
                    ZStack {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        // Keep the material depth from the recorder UI, but make
                        // notifications reliably legible over any foreground app.
                        AppTheme.Surface.control.opacity(0.95)
                        Color.white.opacity(0.025)
                    }
                    .clipShape(Capsule(style: .continuous))
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.20), radius: 14, y: 7)
        .onTapGesture {
            if let onTap = onTap {
                onTap()
                onClose()
            }
        }
    }

}
