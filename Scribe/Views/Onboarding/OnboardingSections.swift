import SwiftUI

struct OnboardingBackground: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}

enum OnboardingLayout {
    static let chromeMaxWidth: CGFloat = 560
    static let horizontalPadding: CGFloat = 48
    static let headerTopPadding: CGFloat = 38
    static let navigationTopPadding: CGFloat = 24
    // Native bordered buttons add their own horizontal chrome around the
    // label. Keeping the label compact produces a balanced 96 pt capsule,
    // rather than an oversized control.
    static let navigationButtonLabelWidth: CGFloat = 64
    static let cardCornerRadius: CGFloat = 14
    static let elevatedSurfaceFill = Color.white.opacity(0.07)
    static let elevatedSurfaceBorder = Color.white.opacity(0.07)
}

struct OnboardingHeroHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(subtitle))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum OnboardingBottomBarPlacement {
    case split
    case centered
}

struct OnboardingCardSurface: View {
    var isSelected = false
    var cornerRadius: CGFloat = OnboardingLayout.cardCornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSelected ? AppTheme.Surface.controlActive : OnboardingLayout.elevatedSurfaceFill)
    }
}

struct OnboardingBottomBar: View {
    let leadingTitle: String?
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    var placement: OnboardingBottomBarPlacement = .split
    let onLeading: (() -> Void)?
    let onPrimary: () -> Void

    @ViewBuilder
    var body: some View {
        switch placement {
        case .split:
            HStack(spacing: 0) {
                leadingSlot
                    .frame(maxWidth: .infinity, alignment: .leading)
                primaryButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        case .centered:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                primaryButton
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var leadingSlot: some View {
        if let leadingTitle, let onLeading {
            Button(action: onLeading) {
                Text(LocalizedStringKey(leadingTitle))
                    .frame(width: OnboardingLayout.navigationButtonLabelWidth)
            }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        } else {
            Color.clear
                .frame(width: OnboardingLayout.navigationButtonLabelWidth, height: 28)
                .accessibilityHidden(true)
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            Text(LocalizedStringKey(primaryTitle))
                .frame(width: OnboardingLayout.navigationButtonLabelWidth)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!isPrimaryEnabled)
    }
}

struct OnboardingStepScreen<Content: View, BottomBar: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let contentMaxWidth: CGFloat
    let showsHeader: Bool
    let contentYOffset: CGFloat
    let content: Content
    let bottomBar: BottomBar

    init(
        stage: OnboardingStage,
        contentMaxWidth: CGFloat,
        showsHeader: Bool = true,
        contentYOffset: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomBar: () -> BottomBar
    ) {
        self.systemImage = stage.systemImage
        self.title = stage.title
        self.subtitle = stage.subtitle
        self.contentMaxWidth = contentMaxWidth
        self.showsHeader = showsHeader
        self.contentYOffset = contentYOffset
        self.content = content()
        self.bottomBar = bottomBar()
    }

    init(
        systemImage: String,
        title: String,
        subtitle: String,
        contentMaxWidth: CGFloat,
        showsHeader: Bool = true,
        contentYOffset: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomBar: () -> BottomBar
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.contentMaxWidth = contentMaxWidth
        self.showsHeader = showsHeader
        self.contentYOffset = contentYOffset
        self.content = content()
        self.bottomBar = bottomBar()
    }

    var body: some View {
        if showsHeader {
            VStack(spacing: 0) {
                bottomBar
                    .frame(maxWidth: .infinity)
                    .padding(.top, OnboardingLayout.navigationTopPadding)

                OnboardingHeroHeader(
                    systemImage: systemImage,
                    title: title,
                    subtitle: subtitle
                )
                .frame(maxWidth: OnboardingLayout.chromeMaxWidth)
                .padding(.top, OnboardingLayout.headerTopPadding)

                Spacer(minLength: 0)

                content
                    .frame(maxWidth: contentMaxWidth)
                    .offset(y: contentYOffset)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
        } else {
            ZStack {
                content
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: contentYOffset)

                VStack(spacing: 0) {
                    bottomBar
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)
                }
                .padding(.top, OnboardingLayout.navigationTopPadding)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}
