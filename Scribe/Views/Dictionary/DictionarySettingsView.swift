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
        Group {
            if #available(macOS 26.0, *) {
                liquidGlassSectionSelector
            } else {
                sectionPicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @available(macOS 26.0, *)
    private var liquidGlassSectionSelector: some View {
        HStack(spacing: 2) {
            liquidGlassSectionButton(.replacements)
            liquidGlassSectionButton(.spellings)
        }
        .padding(3)
        .frame(width: 300, height: 42)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    @available(macOS 26.0, *)
    private func liquidGlassSectionButton(_ section: DictionarySection) -> some View {
        Button {
            selectedSection = section
        } label: {
            Text(section.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(
                    minWidth: section == .replacements ? 172 : nil,
                    maxWidth: section == .spellings ? .infinity : nil,
                    maxHeight: .infinity
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if selectedSection == section {
                Capsule()
                    .fill(Color.white.opacity(0.16))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: selectedSection)
    }

    private var sectionPicker: some View {
        Picker("Dictionary section", selection: $selectedSection) {
            ForEach(DictionarySection.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 320)
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
