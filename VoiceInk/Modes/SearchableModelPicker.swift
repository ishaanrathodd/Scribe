import AppKit
import SwiftUI

/// A native editable macOS combo box. Typing in the selected-model control
/// itself narrows its popup, rather than adding a separate search field.
struct SearchableModelPicker: NSViewRepresentable {
    @Binding var selection: String
    let models: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, models: models)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = true
        comboBox.dataSource = context.coordinator
        comboBox.delegate = context.coordinator
        comboBox.completes = false
        comboBox.isEditable = true
        comboBox.placeholderString = "Search models"
        comboBox.stringValue = selection
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.update(models: models, selection: $selection)
        comboBox.reloadData()

        // Do not overwrite the query while the user is actively filtering.
        if comboBox.currentEditor() == nil, comboBox.stringValue != selection {
            comboBox.stringValue = selection
        }
    }

    final class Coordinator: NSObject, NSComboBoxDataSource, NSComboBoxDelegate {
        private var selection: Binding<String>
        private var allModels: [String]
        private var filteredModels: [String]

        init(selection: Binding<String>, models: [String]) {
            self.selection = selection
            self.allModels = models
            self.filteredModels = models
        }

        func update(models: [String], selection: Binding<String>) {
            self.selection = selection
            allModels = models
            filter(using: currentQuery)
        }

        func numberOfItems(in comboBox: NSComboBox) -> Int {
            filteredModels.count
        }

        func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
            filteredModels[index]
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            filter(using: comboBox.stringValue)
            comboBox.reloadData()
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            let index = comboBox.indexOfSelectedItem
            guard filteredModels.indices.contains(index) else { return }
            selection.wrappedValue = filteredModels[index]
            comboBox.stringValue = filteredModels[index]
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            let typedValue = comboBox.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let exactMatch = allModels.first(where: {
                $0.compare(typedValue, options: .caseInsensitive) == .orderedSame
            }) {
                selection.wrappedValue = exactMatch
                comboBox.stringValue = exactMatch
            } else {
                comboBox.stringValue = selection.wrappedValue
            }
            filter(using: selection.wrappedValue)
        }

        private var currentQuery: String = ""

        private func filter(using query: String) {
            currentQuery = query
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            filteredModels = trimmedQuery.isEmpty
                ? allModels
                : allModels.filter { $0.localizedCaseInsensitiveContains(trimmedQuery) }
        }
    }
}
