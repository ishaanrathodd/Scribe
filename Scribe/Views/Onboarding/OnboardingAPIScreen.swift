import SwiftUI

struct OnboardingAPIScreen: View {
    @ObservedObject var aiService: AIService

    let contentMaxWidth: CGFloat
    let providerOptions: [AIProvider]
    @Binding var selectedProvider: AIProvider
    let isSelectedProviderVerified: Bool
    let canContinue: Bool
    @Binding var isShowingSkipWarning: Bool
    let onVerificationChanged: () -> Void
    let onBack: () -> Void
    let onContinue: () -> Void
    let onRequestSkip: () -> Void
    let onConfirmSkip: () -> Void

    var body: some View {
        OnboardingStepScreen(
            stage: .api,
            contentMaxWidth: contentMaxWidth
        ) {
            AIProviderVerificationCard(
                aiService: aiService,
                providerOptions: providerOptions,
                selectedProvider: $selectedProvider,
                onVerificationChanged: onVerificationChanged
            )
        } bottomBar: {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Text("Back")
                        .frame(width: OnboardingLayout.navigationButtonLabelWidth)
                }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)

                Spacer()

                if !isSelectedProviderVerified {
                    Button("Set Up Later", action: onRequestSkip)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                }

                Button(action: onContinue) {
                    Text("Continue")
                        .frame(width: OnboardingLayout.navigationButtonLabelWidth)
                }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(!(canContinue && isSelectedProviderVerified))
            }
            .frame(maxWidth: .infinity)
        }
        .alert("Set up AI enhancement later?", isPresented: $isShowingSkipWarning) {
            Button("Go Back", role: .cancel) {}
            Button("Set It Up Later") {
                onConfirmSkip()
            }
        } message: {
            Text("Enhancement modes and AI actions will stay off until you add a key. You can set this up anytime from Settings.")
        }
    }
}
