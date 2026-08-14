import SwiftUI

/// A system-style search control rendered with the platform Liquid Glass
/// effect. Keeping the text field unstyled lets macOS provide editing,
/// selection, accessibility, and keyboard behavior.
struct NativeSearchField: View {
    @Binding var text: String
    let placeholder: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                fieldContent
                    .glassEffect(.regular, in: Capsule())
            } else {
                fieldContent
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var fieldContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .frame(minHeight: 36)
    }
}

struct AppIconButton: View {
    let systemName: String
    let help: LocalizedStringResource
    var size: CGFloat = 40
    var iconSize: CGFloat = 18
    var cornerRadius: CGFloat = AppTheme.Radius.pill
    var isDisabled = false
    let action: () -> Void

    init(
        systemName: String,
        help: LocalizedStringResource,
        size: CGFloat = 40,
        iconSize: CGFloat = 18,
        cornerRadius: CGFloat = AppTheme.Radius.pill,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.help = help
        self.size = size
        self.iconSize = iconSize
        self.cornerRadius = cornerRadius
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                iconButton
                    .buttonStyle(.plain)
                    .frame(width: size, height: size)
                    .glassEffect()
            } else {
                iconButton
                    .buttonStyle(.bordered)
                    .controlSize(size <= 28 ? .small : .regular)
            }
        }
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private var iconButton: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.45) : Color.primary)
        }
    }
}

struct AppPanelHeader: View {
    let title: LocalizedStringKey
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Spacer()

            AppIconButton(
                systemName: "xmark",
                help: "Close",
                size: 28,
                iconSize: 14,
                cornerRadius: AppTheme.Radius.control,
                action: onClose
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(Divider().opacity(0.5), alignment: .bottom)
        .zIndex(1)
    }
}

struct AppScreenHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var showsTitle = true
    var infoMessage: LocalizedStringKey?
    var infoURL: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            if showsTitle {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Spacer()

            if let infoMessage {
                if let infoURL {
                    InfoTip(infoMessage, learnMoreURL: infoURL)
                } else {
                    InfoTip(infoMessage)
                }
            }

            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}

extension AppScreenHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey, infoMessage: LocalizedStringKey? = nil, infoURL: String? = nil) {
        self.title = title
        self.infoMessage = infoMessage
        self.infoURL = infoURL
        self.trailing = { EmptyView() }
    }
}
