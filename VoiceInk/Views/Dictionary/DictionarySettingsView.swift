import SwiftUI

struct DictionarySettingsView: View {
    @State private var selectedSection: DictionarySection = .replacements
    @State private var isShowingSettings = false

    enum DictionarySection: String, CaseIterable, Hashable {
        case replacements = "Word Replacements"
        case spellings = "Vocabulary"

        var description: String {
            switch self {
            case .spellings:
                return String(
                    localized:
                        "Vocabulary is used only with AI enhancement to preserve important names, technical terms, and unique spellings in the final output."
                )
            case .replacements:
                return String(
                    localized:
                        "Word Replacements run after transcription to replace misheard words, phrases, abbreviations, or boilerplate text."
                )
            }
        }

    }

    var body: some View {
        VStack(spacing: 0) {
            sectionSelector
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 12)
            selectedSectionForm
        }
        .frame(minWidth: 600, minHeight: 500)
        .sidePanel(isPresented: $isShowingSettings) {
            DictionarySettingsPanel {
                isShowingSettings = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingSettings.toggle()
                } label: {
                    Label("Dictionary Settings", systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .help("Dictionary Settings")
            }
        }
    }

    private var sectionSelector: some View {
        Picker("Dictionary section", selection: $selectedSection) {
            ForEach(DictionarySection.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 320)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var selectedSectionForm: some View {
        Form {
            Section {
                selectedSectionContent
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .spellings:
            VocabularyView()
        case .replacements:
            WordReplacementView()
        }
    }
}
