import SwiftUI

struct PermissionStepRow: View {
    let stepNumber: Int
    let descriptor: OnboardingPermissionDescriptor
    let status: OnboardingPermissionStatus
    let isActive: Bool
    let isLocked: Bool
    let showsRestartHint: Bool
    let actionTitle: String
    let onSelect: () -> Void
    let onAction: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: descriptorSystemImage)
                    .font(.body.weight(.medium))
                    .frame(width: 20)
                    .foregroundStyle(status.isGranted ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(descriptor.title))
                        .font(.body.weight(.medium))

                    Text(LocalizedStringKey(descriptor.subtitle))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if status.isGranted {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.green)
                } else if isLocked {
                    Text("Locked")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button(LocalizedStringKey(actionTitle), action: onAction)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                }
            }

            if isActive && !isLocked && showsRestartHint {
                restartHint
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 12)
        .opacity(isLocked ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLocked else { return }
            onSelect()
        }
    }

    private var descriptorSystemImage: String {
        switch descriptor.title {
        case "Microphone":
            return "mic"
        case "Accessibility":
            return "accessibility"
        default:
            return "rectangle.on.rectangle"
        }
    }

    private var restartHint: some View {
        HStack(spacing: 8) {
            Text("Quit and reopen Scribe after enabling Screen Recording.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Quit") {
                onQuit()
            }
            .buttonStyle(.link)
        }
    }
}
