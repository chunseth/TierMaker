import SwiftUI

struct TemplatePickerView: View {
    @Binding var selectedTemplate: TierTemplate?
    var onSelect: (TierTemplate) -> Void

    @State private var selectedCategory: String?

    var body: some View {
        NavigationStack {
            Group {
                if let category = selectedCategory {
                    categoryTemplatesView(category: category)
                } else {
                    categoryMenuView
                }
            }
            .navigationTitle(selectedCategory ?? "Choose a Tier List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedCategory != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            selectedCategory = nil
                        }
                    }
                }
            }
        }
    }

    private var categoryMenuView: some View {
        List {
            ForEach(TierTemplate.allCategories, id: \.self) { category in
                Button(action: { selectedCategory = category }) {
                    Text(category)
                        .font(.headline)
                }
            }
        }
    }

    private func categoryTemplatesView(category: String) -> some View {
        List {
            ForEach(TierTemplate.templates(forCategory: category), id: \.name) { template in
                Button(action: { onSelect(template) }) {
                    Text(template.name)
                        .font(.headline)
                }
            }
        }
    }
}
