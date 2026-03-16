import Foundation

class GameLogic: ObservableObject {
    @Published var gameState: GameState

    /// Start a new game. Creator is player1; recipient goes first (player2).
    /// - Parameter excludedItemNames: Item names dragged to trash in category customize; they are stored as tier .T (encoded in URL) but not shown in the tier list.
    init(template: TierTemplate, creatorParticipantID: UUID, excludedItemNames: Set<String> = []) {
        let items = template.items.map { tItem in
            var item = Item(name: tItem.name)
            if excludedItemNames.contains(tItem.name) { item.tier = .T }
            return item
        }
        self.gameState = GameState(
            items: items,
            templateName: template.name,
            participant1ID: creatorParticipantID,
            participant2ID: nil,
            currentPlayerID: "player2"
        )
    }

    /// Load existing game from message (e.g. after decoding GameState from MSMessage).
    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Whether it's the given participant's turn.
    func isMyTurn(localParticipantID: UUID) -> Bool {
        gameState.isTurn(of: localParticipantID)
    }

    /// Role for the given participant ("player1" or "player2"), nil if not in game.
    func role(for participantID: UUID) -> String? {
        gameState.role(for: participantID)
    }  
    
    // MARK: - Actions
    
    func placeItem(_ item: Item, inTier tier: Tier) -> Bool {
        let countInTier = gameState.items.filter { $0.tier == tier }.count
        return placeItem(item, inTier: tier, atIndexInTier: countInTier)
    }

    func placeItem(_ item: Item, inTier tier: Tier, atIndexInTier indexInTier: Int) -> Bool {
        guard !gameState.isComplete else { return false }
        guard gameState.items.contains(where: { $0.id == item.id && $0.tier == nil }) else {
            return false // Item already ranked
        }
        gameState.placeItem(item, inTier: tier, atIndexInTier: indexInTier)
        if gameState.isComplete {
            gameState.isGameOver = true
        }
        return true
    }

    /// Move an already-ranked item to another tier or reorder within same tier (app-only). Does not switch turn.
    func moveItem(_ item: Item, toTier tier: Tier, atIndexInTier indexInTier: Int) -> Bool {
        guard gameState.items.contains(where: { $0.id == item.id && $0.tier != nil }) else {
            return false
        }
        gameState.moveRankedItem(item, toTier: tier, atIndexInTier: indexInTier)
        return true
    }
    
    func challengePlacement(_ item: Item, moveToTier tier: Tier) -> Bool {
        guard !gameState.isComplete else { return false }
        guard let rankedItem = gameState.items.first(where: { $0.id == item.id }),
              rankedItem.tier != nil else {
            return false // Item not ranked yet
        }
        gameState.challengeItem(item, moveToTier: tier)
        return true
    }

    /// Veto: move the item one tier up or down. New tier must be adjacent to current. Returns true if move was applied.
    func vetoItem(_ item: Item, toTier newTier: Tier) -> Bool {
        guard !gameState.isComplete else { return false }
        return gameState.vetoMove(item, toTier: newTier)
    }

    /// Set item's tier without switching turn (for undoing a veto).
    func setItemTier(_ item: Item, to tier: Tier) {
        gameState.setItemTier(item, to: tier)
    }

    /// Move item back to unranked (e.g. undo before Done). Does not switch turn.
    func unrankItem(_ item: Item) {
        gameState.unrankItem(item)
    }

    /// Unrank item and move it to the end of the unranked list (e.g. when lifting from tier to drag). Does not switch turn.
    func unrankItemAndMoveToEndOfUnranked(_ item: Item) {
        gameState.unrankItemAndMoveToEndOfUnranked(item)
    }

    /// Revert turn to the other player (e.g. after unranking so current player can place again).
    func revertTurn() {
        gameState.revertTurn()
    }

    /// Restore the index of the opponent's last-placed item (e.g. after undoing our placement so purple border returns).
    func setLastPlacedItemIndex(_ index: Int?) {
        gameState.lastPlacedItemIndex = index
    }

    /// Clear last-move-was-veto (e.g. after undoing a veto so the item can be vetoed again).
    func setLastMoveWasVeto(_ value: Bool) {
        gameState.lastMoveWasVeto = value
    }

    // MARK: - State Serialization
    
    func encodeState() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(gameState)
    }
    
    static func decodeState(_ data: Data) -> GameState? {
        let decoder = JSONDecoder()
        return try? decoder.decode(GameState.self, from: data)
    }
}
