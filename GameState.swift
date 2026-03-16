import Foundation
import Compression

// Tier levels: S=1, A=2, B=3, C=4, D=5, T=6 (trash = excluded in category pick; not shown in list/preview/final)
enum Tier: Int, Codable, CaseIterable {
    case S = 1
    case A = 2
    case B = 3
    case C = 4
    case D = 5
    case T = 6  // Trash: placed during category selection, encoded in URL, never displayed

    /// Tiers shown in the tier list UI, preview, and final image (excludes trash).
    static var displayTiers: [Tier] { [.S, .A, .B, .C, .D] }

    var displayName: String {
        switch self {
        case .S: return "S"
        case .A: return "A"
        case .B: return "B"
        case .C: return "C"
        case .D: return "D"
        case .T: return "T"
        }
    }

    /// One tier stricter (e.g. A → S). Nil if already S or T.
    var tierAbove: Tier? { self == .T ? nil : Tier(rawValue: rawValue - 1) }
    /// One tier looser (e.g. A → B). Nil if already D or T.
    var tierBelow: Tier? { self == .T ? nil : Tier(rawValue: rawValue + 1) }
}

struct Item: Codable, Identifiable {
    let id: UUID
    let name: String
    var tier: Tier?
    var challenged: Bool = false
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.tier = nil
    }
}

struct GameState: Codable {
    var items: [Item]
    var templateName: String
    /// Creator of the game (sender of first message)
    var participant1ID: UUID
    /// Second player (nil until they open the message)
    var participant2ID: UUID?
    var currentPlayerID: String // "player1" or "player2"
    var isGameOver: Bool = false
    var gameHistory: [GameMove] = []
    /// Index (into items) of the item last placed/moved by the player who just acted. Used to show opponent's last-placed (purple border).
    var lastPlacedItemIndex: Int?
    /// True if the last move was a veto. Next player cannot veto (no purple border).
    var lastMoveWasVeto: Bool = false

    /// Resolve second participant when they first open the message
    mutating func setParticipant2IfNeeded(_ participantID: UUID) {
        if participant2ID == nil && participantID != participant1ID {
            participant2ID = participantID
        }
    }
    
    /// Whether the given participant's turn it is
    func isTurn(of participantID: UUID) -> Bool {
        if participantID == participant1ID { return currentPlayerID == "player1" }
        if participantID == participant2ID { return currentPlayerID == "player2" }
        return false
    }
    
    /// Which role the participant has ("player1" or "player2"), nil if not in game
    func role(for participantID: UUID) -> String? {
        if participantID == participant1ID { return "player1" }
        if participantID == participant2ID { return "player2" }
        return nil
    }
    
    var unrankedItems: [Item] {
        items.filter { $0.tier == nil }
    }
    
    var isComplete: Bool {
        unrankedItems.isEmpty
    }
    
    mutating func placeItem(_ item: Item, inTier tier: Tier) {
        placeItem(item, inTier: tier, atIndexInTier: items.filter { $0.tier == tier }.count)
    }

    /// Place item in tier at a specific index (order within tier). Moves item in the array so tier order is preserved.
    mutating func placeItem(_ item: Item, inTier tier: Tier, atIndexInTier indexInTier: Int) {
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        var moved = items.remove(at: currentIndex)
        moved.tier = tier
        moved.challenged = false

        let indicesInTier = items.indices.filter { items[$0].tier == tier }.sorted()
        let insertIndex: Int
        if indicesInTier.isEmpty {
            insertIndex = 0
        } else if indexInTier <= 0 {
            insertIndex = indicesInTier[0]
        } else if indexInTier >= indicesInTier.count {
            insertIndex = indicesInTier.last! + 1
        } else {
            insertIndex = indicesInTier[indexInTier]
        }
        items.insert(moved, at: insertIndex)
        lastPlacedItemIndex = insertIndex
        lastMoveWasVeto = false
        gameHistory.append(GameMove(
            playerID: currentPlayerID,
            itemID: item.id,
            action: .placed(tier)
        ))
        currentPlayerID = currentPlayerID == "player1" ? "player2" : "player1"
    }

    /// Veto: move item one tier up or down. New tier must be adjacent to current. Switches turn.
    mutating func vetoMove(_ item: Item, toTier newTier: Tier) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              let currentTier = items[index].tier,
              (newTier == currentTier.tierAbove || newTier == currentTier.tierBelow) else {
            return false
        }
        items[index].tier = newTier
        items[index].challenged = false
        lastPlacedItemIndex = index
        lastMoveWasVeto = true
        gameHistory.append(GameMove(
            playerID: currentPlayerID,
            itemID: item.id,
            action: .placed(newTier)
        ))
        currentPlayerID = currentPlayerID == "player1" ? "player2" : "player1"
        return true
    }

    /// Remove item from tier (e.g. undo before sending). Does not switch turn.
    mutating func unrankItem(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].tier = nil
            items[index].challenged = false
        }
    }

    /// Unrank the item and move it to the end of the unranked list (for drag-from-tier: no phantom slot). Does not switch turn.
    mutating func unrankItemAndMoveToEndOfUnranked(_ item: Item) {
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        var moved = items.remove(at: currentIndex)
        moved.tier = nil
        moved.challenged = false
        let insertIndex: Int
        if let lastUnranked = items.indices.last(where: { items[$0].tier == nil }) {
            insertIndex = lastUnranked + 1
        } else {
            insertIndex = 0
        }
        items.insert(moved, at: insertIndex)
    }

    /// Move an already-ranked item to another tier or reorder within same tier. Does not switch turn or append history (app-only rearrange).
    mutating func moveRankedItem(_ item: Item, toTier tier: Tier, atIndexInTier indexInTier: Int) {
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }),
              items[currentIndex].tier != nil else { return }
        var moved = items.remove(at: currentIndex)
        moved.tier = tier
        moved.challenged = false

        let indicesInTier = items.indices.filter { items[$0].tier == tier }.sorted()
        let insertIndex: Int
        if indicesInTier.isEmpty {
            insertIndex = 0
        } else if indexInTier <= 0 {
            insertIndex = indicesInTier[0]
        } else if indexInTier >= indicesInTier.count {
            insertIndex = indicesInTier.last! + 1
        } else {
            insertIndex = indicesInTier[indexInTier]
        }
        items.insert(moved, at: insertIndex)
    }

    /// Revert turn to the other player (e.g. after unranking the just-placed item in message mode).
    mutating func revertTurn() {
        currentPlayerID = currentPlayerID == "player1" ? "player2" : "player1"
    }

    /// Set item's tier without switching turn or appending history (e.g. undo a veto).
    mutating func setItemTier(_ item: Item, to tier: Tier) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].tier = tier
        }
    }
    
    mutating func challengeItem(_ item: Item, moveToTier tier: Tier) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let originalTier = items[index].tier ?? .D
            let resolvedTier = averageTiers(originalTier, tier)
            
            items[index].tier = resolvedTier
            items[index].challenged = true
            
            // Log move
            gameHistory.append(GameMove(
                playerID: currentPlayerID,
                itemID: item.id,
                action: .challenged(originalTier, tier, resolvedTier)
            ))
            
            // Switch turn
            currentPlayerID = currentPlayerID == "player1" ? "player2" : "player1"
        }
    }
    
    private func averageTiers(_ tier1: Tier, _ tier2: Tier) -> Tier {
        let avg = Double(tier1.rawValue + tier2.rawValue) / 2.0
        let rounded = Int(avg.rounded(.up)) // Round up to stricter tier
        return Tier(rawValue: rounded) ?? .D
    }
    
    // MARK: - Message encoding (for MSMessage.url)
    
    /// MSMessage.url only accepts http/https (custom schemes become nil). Use https so the URL is accepted.
    private static let urlScheme = "https"
    private static let urlHost = "tierlist.game"
    private static let urlPath = "/g"
    private static let urlQueryKey = "state"
    
    /// Compact format for URL: template index + tier per item (no UUIDs/names). Stays under iMessage URL limit.
    private struct CompactState: Codable {
        let ti: Int           // template index in TierTemplate.all
        let p1: String        // participant1ID uuidString
        let p2: String?       // participant2ID uuidString
        let c: String         // currentPlayerID "1" or "2"
        let o: Bool           // isGameOver
        let t: [Int]          // tier rawValue per template index, 0 = unranked
        let ord: [Int]?       // optional: display order = template indices in placement order (preserves order within tiers)
        let lp: Int?          // lastPlacedItemIndex (item last placed by the player who just moved)
        let v: Bool?          // lastMoveWasVeto (next player cannot veto if true)
    }
    
    func encodeToMessageURL() -> URL? {
        guard let compact = toCompact(),
              let data = try? JSONEncoder().encode(compact),
              let compressed = data.compressed() else { return nil }
        let base64url = compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        var components = URLComponents()
        components.scheme = GameState.urlScheme
        components.host = GameState.urlHost
        components.path = GameState.urlPath
        components.queryItems = [URLQueryItem(name: GameState.urlQueryKey, value: base64url)]
        return components.url
    }
    
    private func toCompact() -> CompactState? {
        guard let templateIndex = TierTemplate.all.firstIndex(where: { $0.name == templateName }) else { return nil }
        let template = TierTemplate.all[templateIndex]
        // t[i] = tier of template item i (so decoder can look up by template index)
        let tiers = (0..<template.items.count).map { i in
            items.first(where: { $0.name == template.items[i].name })?.tier?.rawValue ?? 0
        }
        // Display order: template indices in items array order (preserves order within tiers)
        let order = items.map { item in
            template.items.firstIndex(where: { $0.name == item.name })!
        }
        return CompactState(
            ti: templateIndex,
            p1: participant1ID.uuidString,
            p2: participant2ID?.uuidString,
            c: currentPlayerID == "player1" ? "1" : "2",
            o: isGameOver,
            t: tiers,
            ord: order,
            lp: lastPlacedItemIndex,
            v: lastMoveWasVeto
        )
    }
    
    private static func fromCompact(_ compact: CompactState) -> GameState? {
        guard compact.ti >= 0, compact.ti < TierTemplate.all.count,
              let p1 = UUID(uuidString: compact.p1) else { return nil }
        let template = TierTemplate.all[compact.ti]
        let items: [Item]
        if let order = compact.ord, order.count == compact.t.count,
           Set(order) == Set(0..<template.items.count) {
            // Rebuild items in display order (preserves order within tiers)
            items = order.map { idx in
                var item = Item(name: template.items[idx].name)
                if idx < compact.t.count, compact.t[idx] != 0, let tier = Tier(rawValue: compact.t[idx]) {
                    item.tier = tier
                }
                return item
            }
        } else {
            // Legacy: template order
            var legacyItems = template.items.map { Item(name: $0.name) }
            for i in legacyItems.indices where i < compact.t.count && compact.t[i] != 0 {
                if let tier = Tier(rawValue: compact.t[i]) {
                    legacyItems[i].tier = tier
                }
            }
            items = legacyItems
        }
        let p2: UUID? = compact.p2.flatMap { UUID(uuidString: $0) }
        var state = GameState(
            items: items,
            templateName: template.name,
            participant1ID: p1,
            participant2ID: p2,
            currentPlayerID: compact.c == "1" ? "player1" : "player2",
            isGameOver: compact.o,
            gameHistory: []
        )
        state.lastPlacedItemIndex = compact.lp
        state.lastMoveWasVeto = compact.v ?? false
        return state
    }

    static func decode(from messageURL: URL) -> GameState? {
        guard let queryItems = URLComponents(url: messageURL, resolvingAgainstBaseURL: false)?.queryItems,
              let encoded = queryItems.first(where: { $0.name == urlQueryKey })?.value else {
            return nil
        }
        return decode(fromEncodedQueryValue: encoded)
    }

    /// Decode from raw "state" query: try compact format first (compressed), then legacy full JSON.
    static func decode(fromEncodedQueryValue encoded: String) -> GameState? {
        let raw = encoded.removingPercentEncoding ?? encoded
        let standard = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - standard.count % 4) % 4
        let padded = standard + String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: padded) else { return nil }
        for algorithm in [COMPRESSION_LZFSE, COMPRESSION_ZLIB] {
            if let decompressed = data.decompressed(algorithm: algorithm),
               let compact = try? JSONDecoder().decode(CompactState.self, from: decompressed),
               let state = fromCompact(compact) {
                return state
            }
        }
        if let decompressed = data.decompressed(algorithm: COMPRESSION_LZFSE), let state = try? JSONDecoder().decode(GameState.self, from: decompressed) {
            return state
        }
        if let decompressed = data.decompressed(algorithm: COMPRESSION_ZLIB), let state = try? JSONDecoder().decode(GameState.self, from: decompressed) {
            return state
        }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }

    func encodeToData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> GameState? {
        try? JSONDecoder().decode(GameState.self, from: data)
    }
}

// MARK: - Data compression (for MSMessage URL length limit)

extension Data {
    func compressed() -> Data? {
        let destSize = count + (count / 100) + 32
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        defer { dest.deallocate() }
        let written = withUnsafeBytes { src in
            compression_encode_buffer(dest, destSize, src.bindMemory(to: UInt8.self).baseAddress!, count, nil, COMPRESSION_LZFSE)
        }
        guard written > 0 else { return nil }
        return Data(bytes: dest, count: written)
    }

    func decompressed(algorithm: compression_algorithm = COMPRESSION_LZFSE) -> Data? {
        let destCapacity = 2 * 1024 * 1024
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
        defer { dest.deallocate() }
        let written = withUnsafeBytes { src in
            compression_decode_buffer(dest, destCapacity, src.bindMemory(to: UInt8.self).baseAddress!, count, nil, algorithm)
        }
        guard written > 0 else { return nil }
        return Data(bytes: dest, count: written)
    }
}

struct GameMove: Codable {
    let playerID: String
    let itemID: UUID
    let action: MoveAction
    let timestamp: Date = Date()
}

enum MoveAction: Codable {
    case placed(Tier)
    case challenged(Tier, Tier, Tier) // original, challenger's, resolved
    
    enum CodingKeys: String, CodingKey {
        case placed
        case challenged
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let tier = try container.decodeIfPresent(Tier.self, forKey: .placed) {
            self = .placed(tier)
        } else if let values = try container.decodeIfPresent([Tier].self, forKey: .challenged),
                  values.count == 3 {
            self = .challenged(values[0], values[1], values[2])
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid MoveAction")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .placed(let tier):
            try container.encode(tier, forKey: .placed)
        case .challenged(let orig, let chal, let res):
            try container.encode([orig, chal, res], forKey: .challenged)
        }
    }
}
