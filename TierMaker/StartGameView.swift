import SwiftUI

/// Shown when the extension opens with no selected message. User picks a category, then a template, customizes (optional trash), then we send an MSMessage to start the game.
struct StartGameView: View {
    /// Called with (template, excludedItemNames) when user taps Done on the category customize screen.
    var onSelectTemplate: (TierTemplate, Set<String>) -> Void
    /// Called when user selects a category (so the host can e.g. expand the extension).
    var onCategorySelected: (() -> Void)?

    @State private var selectedCategory: String?
    @State private var selectedTemplate: TierTemplate?

    var body: some View {
        NavigationStack {
            Group {
                if let template = selectedTemplate {
                    CategoryCustomizeView(template: template) { excludedNames in
                        onSelectTemplate(template, excludedNames)
                    }
                } else if let category = selectedCategory {
                    categoryTemplatesView(category: category)
                } else {
                    categoryMenuView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(navigationTitle)
            .toolbar {
                if selectedCategory != nil || selectedTemplate != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            if selectedTemplate != nil {
                                selectedTemplate = nil
                            } else {
                                selectedCategory = nil
                            }
                        }
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        if selectedTemplate != nil {
            return "Customize"
        }
        if let category = selectedCategory {
            return category
        }
        return "Make a Tier List"
    }

    private var categoryMenuView: some View {
        List {
            ForEach(TierTemplate.allCategories, id: \.self) { category in
                Button(action: {
                    selectedCategory = category
                    onCategorySelected?()
                }) {
                    Text(category)
                        .font(.headline)
                }
            }
        }
    }

    private func categoryTemplatesView(category: String) -> some View {
        List {
            ForEach(TierTemplate.templates(forCategory: category), id: \.name) { template in
                Button(action: {
                    selectedTemplate = template
                    onCategorySelected?()
                }) {
                    Text(template.name)
                        .font(.headline)
                }
            }
        }
    }
}
