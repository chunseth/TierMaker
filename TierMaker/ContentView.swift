import SwiftUI

struct ContentView: View {
    @State private var gameLogic: GameLogic?
    @State private var selectedTemplate: TierTemplate?

    var body: some View {
        Group {
            if let gameLogic = gameLogic {
                NavigationStack {
                    GameBoardView(gameLogic: gameLogic)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("New Game") {
                                    self.gameLogic = nil
                                    selectedTemplate = nil
                                }
                            }
                        }
                }
            } else if let template = selectedTemplate {
                NavigationStack {
                    CategoryCustomizeView(template: template) { excludedNames in
                        gameLogic = GameLogic(
                            template: template,
                            creatorParticipantID: UUID(),
                            excludedItemNames: excludedNames
                        )
                        selectedTemplate = nil
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                selectedTemplate = nil
                            }
                        }
                    }
                }
            } else {
                TemplatePickerView(selectedTemplate: $selectedTemplate) { template in
                    selectedTemplate = template
                }
            }
        }
    }
}

#Preview {
    ContentView()
}            
