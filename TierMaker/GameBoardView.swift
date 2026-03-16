import SwiftUI
import UIKit

/// Wraps a tier list image for sheet presentation and sharing (Identifiable).
private struct ShareableTierListImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Gesture + hit-test: preference keys for drop-target frames

private struct UnrankedItemFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, n in n })
    }
}

/// Unranked item frames in global (screen) coordinates for accurate drag positioning when content is in a host (e.g. vertical-claim wrapper).
private struct UnrankedItemGlobalFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, n in n })
    }
}

/// Board container frame in global coordinates so we can convert finger position (global) to board space for overlay and hit-test.
private struct BoardFrameInGlobalKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

private struct TierFramesKey: PreferenceKey {
    static var defaultValue: [Tier: CGRect] { [:] }
    static func reduce(value: inout [Tier: CGRect], nextValue: () -> [Tier: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, n in n })
    }
}

/// Per-item frame within a tier row (for insertion-index hit-test and drag-from-tier start position).
private struct TierItemFrameEntry: Equatable {
    let tier: Tier
    let itemId: UUID
    let frame: CGRect
}

private struct TierItemFramesKey: PreferenceKey {
    static var defaultValue: [TierItemFrameEntry] { [] }
    static func reduce(value: inout [TierItemFrameEntry], nextValue: () -> [TierItemFrameEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// Tier item frames in global coordinates (for drag-from-tier so preview follows finger).
private struct TierItemGlobalFrameEntry: Equatable {
    let itemId: UUID
    let frame: CGRect
}

private struct TierItemGlobalFramesKey: PreferenceKey {
    static var defaultValue: [TierItemGlobalFrameEntry] { [] }
    static func reduce(value: inout [TierItemGlobalFrameEntry], nextValue: () -> [TierItemGlobalFrameEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// Unranked zone frame in board space (for drop-in-unranked hit-test).
private struct UnrankedZoneFrameInBoardKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

/// Tier-rows overlay frame in global (so overlay gesture can convert to board space).
private struct TierRowsOverlayFrameInGlobalKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

struct GameBoardView: View {
    @ObservedObject var gameLogic: GameLogic
    /// When non-nil, we're in iMessage turn-based mode: show Done, respect turns.
    var localParticipantID: UUID? = nil
    /// Called when user taps Done to send updated state (extension only).
    var onDone: (() -> Void)? = nil

    @State private var draggedItem: Item?
    @State private var hoveredTier: Tier?
    /// When dragging, (tier, indexInTier) where the item would be inserted. Used to show placeholder.
    @State private var hoveredDropTarget: (Tier, Int)?
    /// In message mode, one placement per turn then Done.
    @State private var hasPlacedThisTurn = false
    /// In extension (tap-to-place): selected item before tapping a tier.
    @State private var selectedItem: Item?
    /// In message mode, the item just placed this turn (tap it to unrank; avoids drag in extension).
    @State private var lastPlacedItem: Item?
    /// True if this turn was a veto (show "Veto!" button).
    @State private var hasVetoedThisTurn = false
    /// When we vetoed, the tier the item was in before (for tap-to-undo).
    @State private var lastVetoedFromTier: Tier?
    /// Index of opponent's last-placed item before we placed; restored when we undo our placement.
    @State private var savedOpponentLastPlacedIndex: Int?
    /// Show veto up/down arrows on the purple item after user taps it.
    @State private var showVetoArrowsForItemID: UUID?
    // Gesture + hit-test: track drag with start frame + translation.
    @State private var pointerDragItem: Item?
    @State private var pointerDragStartFrame: CGRect?
    @State private var pointerDragTranslation: CGSize = .zero
    /// Drag start in global coordinates so we can add gesture delta for accurate position (unranked zone may be in a host).
    @State private var pointerDragStartInGlobal: CGPoint?
    /// Current drag position in board space (from global coords); keeps preview under finger when unranked zone is in a host.
    @State private var pointerDragCurrentBoard: CGPoint?
    /// When true, this gesture was treated as scroll (horizontal); don't commit to item drag.
    @State private var pointerDragScrollCancelled = false
    /// When true, user dragged down past vertical threshold first; never treat as scroll.
    @State private var pointerDragCommittedToDrag = false
    @State private var unrankedItemFrames: [UUID: CGRect] = [:]
    @State private var unrankedItemGlobalFrames: [UUID: CGRect] = [:]
    @State private var boardFrameInGlobal: CGRect = .zero
    @State private var tierFrames: [Tier: CGRect] = [:]
    /// Frames of items in each tier row (left-to-right order) for insertion-index hit-test.
    @State private var tierItemFrames: [Tier: [CGRect]] = [:]
    /// Frame in board space per tier item (for drag-from-tier start position).
    @State private var tierItemFrameByItemId: [UUID: CGRect] = [:]
    /// Frame in global space per tier item (for drag-from-tier so preview follows finger).
    @State private var tierItemGlobalFrameByItemId: [UUID: CGRect] = [:]
    /// Unranked zone frame in board space (for drop-in-unranked to return item to unranked).
    @State private var unrankedZoneFrameInBoard: CGRect?
    /// Tier-rows-only overlay frame in global (for converting gesture location to board space).
    @State private var tierRowsOverlayFrameInGlobal: CGRect = .zero
    /// When non-nil, present share sheet for this tier list image (app only, after Done).
    @State private var shareableTierListImage: ShareableTierListImage?
    @State private var isRenderingTierListImage = false

    private var isMessageMode: Bool { onDone != nil }
    private var isMyTurn: Bool {
        guard let id = localParticipantID else { return true }
        return gameLogic.isMyTurn(localParticipantID: id)
    }
    private var canPlace: Bool {
        if !isMessageMode { return true }
        return isMyTurn && !hasPlacedThisTurn && !gameLogic.gameState.isComplete
    }
    /// In message mode, can unrank only the item just placed (until Done).
    private var canUnrank: Bool {
        if !isMessageMode { return true }
        return hasPlacedThisTurn
    }
    /// Opponent's last-placed item (show purple border; tap to show Move up / Move down). Nil if last move was a veto (next player can't veto).
    private var opponentLastPlacedItem: Item? {
        guard isMessageMode, isMyTurn, !gameLogic.gameState.lastMoveWasVeto,
              let idx = gameLogic.gameState.lastPlacedItemIndex,
              idx >= 0, idx < gameLogic.gameState.items.count else { return nil }
        return gameLogic.gameState.items[idx]
    }
    /// Can veto this turn: my turn, haven't acted yet, opponent has a last-placed item, and last move was not a veto.
    private var canVeto: Bool {
        isMessageMode && isMyTurn && !hasPlacedThisTurn && opponentLastPlacedItem != nil && !gameLogic.gameState.isComplete
    }
    /// Show Done when user has placed this turn (state already switched turn) or game is complete.
    private var showDoneButton: Bool {
        isMessageMode && (hasPlacedThisTurn || gameLogic.gameState.isComplete)
    }

    /// Show "Waiting" only when it's not my turn and I haven't just placed (so I'm not about to send).
    private var showWaitingForOpponent: Bool {
        isMessageMode && !isMyTurn && !hasPlacedThisTurn
    }

    /// Use pointer-style drag (tap → drag → release on tile) everywhere. Same pattern as Game Pigeon: no system DnD, just gesture + hit-test on end.
    private var usePointerDrag: Bool { true }

    /// If horizontal movement is past this and strictly greater than vertical (not yet committed to drag), treat as scroll.
    private static let minScrollDirectionThreshold: CGFloat = 15
    /// If user drags down this much first, commit to item drag and ignore horizontal-scroll cancel.
    private static let verticalDragCommitThreshold: CGFloat = 50
    /// Minimum movement before committing to item drag (so scroll can win if horizontal first).
    private static let dragCommitThreshold: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            gameContent
        }
        .coordinateSpace(name: "board")
        .background(GeometryReader { geo in
            Color.clear.preference(key: BoardFrameInGlobalKey.self, value: geo.frame(in: .global))
        })
        .onPreferenceChange(UnrankedItemFramesKey.self) { unrankedItemFrames = $0 }
        .onPreferenceChange(UnrankedItemGlobalFramesKey.self) { unrankedItemGlobalFrames = $0 }
        .onPreferenceChange(BoardFrameInGlobalKey.self) { boardFrameInGlobal = $0 ?? .zero }
        .onPreferenceChange(TierFramesKey.self) { tierFrames = $0 }
        .onPreferenceChange(TierItemFramesKey.self) { entries in
            tierItemFrames = Dictionary(grouping: entries, by: \.tier).mapValues { es in
                es.sorted {
                    if abs($0.frame.minY - $1.frame.minY) > 5 {
                        return $0.frame.minY < $1.frame.minY
                    }
                    return $0.frame.minX < $1.frame.minX
                }.map(\.frame)
            }
            tierItemFrameByItemId = Dictionary(uniqueKeysWithValues: entries.map { ($0.itemId, $0.frame) })
        }
        .onPreferenceChange(TierItemGlobalFramesKey.self) { entries in
            tierItemGlobalFrameByItemId = Dictionary(uniqueKeysWithValues: entries.map { ($0.itemId, $0.frame) })
        }
        .onPreferenceChange(UnrankedZoneFrameInBoardKey.self) { unrankedZoneFrameInBoard = $0 }
        .onPreferenceChange(TierRowsOverlayFrameInGlobalKey.self) { tierRowsOverlayFrameInGlobal = $0 ?? .zero }
        .overlay {
            if usePointerDrag, let item = pointerDragItem {
                let (dropX, dropY): (CGFloat, CGFloat) = if let board = pointerDragCurrentBoard {
                    (board.x, board.y)
                } else if let start = pointerDragStartFrame {
                    (start.midX + pointerDragTranslation.width, start.midY + pointerDragTranslation.height)
                } else {
                    (0, 0)
                }
                ItemImageView(item: item, gameLogic: gameLogic, isDragged: false)
                    .frame(width: 80, height: 80)
                    .shadow(radius: 8)
                    .position(x: dropX, y: dropY)
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle(gameLogic.gameState.templateName)
        .sheet(item: $shareableTierListImage) { shareable in
            ShareSheetView(image: shareable.image)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showDoneButton {
                Button(action: { onDone?() }) {
                    Text(hasVetoedThisTurn ? "Veto!" : "Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(hasVetoedThisTurn ? Color.purple : nil)
                .padding(8)
                .background(Color(uiColor: .systemBackground))
            }
        }
    }

    /// When usePointerDrag: overlay only on tier rows so unranked zone can scroll. Starts drag from tier by hit-test, moves to unranked on start (no phantom).
    private var tierRowsDragOverlay: some View {
        Group {
            if usePointerDrag {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: TierRowsOverlayFrameInGlobalKey.self, value: geo.frame(in: .global))
                    })
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let locInGlobal = CGPoint(
                                    x: tierRowsOverlayFrameInGlobal.minX + value.location.x,
                                    y: tierRowsOverlayFrameInGlobal.minY + value.location.y
                                )
                                let startInGlobal = CGPoint(
                                    x: locInGlobal.x - value.translation.width,
                                    y: locInGlobal.y - value.translation.height
                                )
                                if pointerDragItem == nil {
                                    if let item = tierItemAtGlobalPoint(startInGlobal) {
                                        pointerDragItem = item
                                        gameLogic.unrankItemAndMoveToEndOfUnranked(item)
                                        pointerDragStartInGlobal = startInGlobal
                                    }
                                }
                                if pointerDragItem != nil {
                                    pointerDragCurrentBoard = globalToBoard(locInGlobal)
                                    pointerDragTranslation = value.translation
                                    hoveredDropTarget = resolveDropTarget(at: globalToBoard(locInGlobal))
                                }
                            }
                            .onEnded { value in
                                if pointerDragItem != nil {
                                    let endInGlobal = CGPoint(
                                        x: tierRowsOverlayFrameInGlobal.minX + value.location.x,
                                        y: tierRowsOverlayFrameInGlobal.minY + value.location.y
                                    )
                                    resolvePointerDrop(dropPointInBoard: globalToBoard(endInGlobal))
                                }
                                clearPointerDrag()
                            }
                    )
            }
        }
    }

    /// Hit-test global point against tier item frames only (used by tier-rows overlay).
    private func tierItemAtGlobalPoint(_ global: CGPoint) -> Item? {
        for (itemId, frame) in tierItemGlobalFrameByItemId where frame.contains(global) {
            return gameLogic.gameState.items.first { $0.id == itemId }
        }
        return nil
    }

    /// Game content (hints + unranked + tiers). In message mode, drags here are consumed so the system doesn't minimize the extension.
    private var gameContent: some View {
        VStack(spacing: 0) {
            gameContentHints
            unrankedZoneSection
            tierRowsSection
        }
    }

    private var gameContentHints: some View {
        Group {
            if !isMessageMode {
                Text("Drag items between tiers or reorder within a tier")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if showWaitingForOpponent {
                Text("Waiting for opponent's turn…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            if isMessageMode && isMyTurn && canPlace {
                Text("Drag item to tier to place")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if isMessageMode && hasPlacedThisTurn {
                Text(hasVetoedThisTurn ? "Tap the orange-bordered item to undo veto, or tap Veto! to send" : "Tap the orange-bordered item to undo, or tap Done to send")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if isMessageMode && isMyTurn && !hasPlacedThisTurn && opponentLastPlacedItem != nil {
                Text("Tap the purple-bordered item to show up/down arrows, then tap an arrow to veto. Or place a new item.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var tierRowsSection: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Tier.displayTiers, id: \.self) { tier in
                    TierRowView(
                        tier: tier,
                        gameLogic: gameLogic,
                        draggedItem: draggedItem,
                        pointerDragItem: pointerDragItem,
                        tierRowScrollEnabled: isMessageMode,
                        hoveredTier: $hoveredTier,
                        insertionIndexInTier: hoveredDropTarget?.0 == tier ? hoveredDropTarget?.1 : nil,
                        selectedItem: isMessageMode ? selectedItem : nil,
                        lastPlacedItemID: isMessageMode ? lastPlacedItem?.id : nil,
                        opponentLastPlacedItemID: isMessageMode ? opponentLastPlacedItem?.id : nil,
                        canVeto: canVeto,
                        showVetoArrowsForItemID: showVetoArrowsForItemID,
                        onTapPurpleItem: canVeto ? { showVetoArrowsForItemID = $0.id } : nil,
                        onVetoMoveUp: canVeto ? { item in applyVeto(item: item, from: tier, to: tier.tierAbove) } : nil,
                        onVetoMoveDown: canVeto ? { item in applyVeto(item: item, from: tier, to: tier.tierBelow) } : nil,
                        onDrop: { item in
                            placeItem(item, inTier: tier)
                            draggedItem = nil
                        },
                        onTapTier: isMessageMode ? {
                            if let item = selectedItem {
                                placeItem(item, inTier: tier)
                                selectedItem = nil
                            }
                        } : nil,
                        onTapItemToUnrank: isMessageMode && canUnrank ? { item in
                            if hasVetoedThisTurn, let fromTier = lastVetoedFromTier {
                                gameLogic.setItemTier(item, to: fromTier)
                                gameLogic.revertTurn()
                                let idx = gameLogic.gameState.items.firstIndex(where: { $0.id == item.id })
                                gameLogic.setLastPlacedItemIndex(idx)
                                gameLogic.setLastMoveWasVeto(false)
                            } else {
                                gameLogic.unrankItem(item)
                                gameLogic.revertTurn()
                                gameLogic.setLastPlacedItemIndex(savedOpponentLastPlacedIndex)
                            }
                            hasPlacedThisTurn = false
                            hasVetoedThisTurn = false
                            lastPlacedItem = nil
                            lastVetoedFromTier = nil
                            selectedItem = nil
                        } : nil,
                        onBeginDragFromTier: (isMessageMode || usePointerDrag) ? nil : { item in beginPointerDragFromTier(item: item) },
                        onDragTierItemChanged: (isMessageMode || usePointerDrag) ? nil : { item, value in updatePointerDragFromTier(item: item, value: value) },
                        onDragTierItemEnded: (isMessageMode || usePointerDrag) ? nil : { item, value in endPointerDragFromTier(item: item, value: value) }
                    )
                    .frame(height: isMessageMode ? 100 : nil)
                    .frame(minHeight: 86)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TierFramesKey.self, value: [tier: geo.frame(in: .named("board"))])
                        }
                    )
                    .background(hoveredTier == tier ? Color.white.opacity(0.1) : Color.clear)
                    .allowsHitTesting(canPlace || canUnrank || canVeto || !isMessageMode)
                }
            }
            .background {
                if !isMessageMode {
                    TwoFingerScrollPatcher()
                }
            }
            .overlay { tierRowsDragOverlay }
        }
        .scrollIndicators(.visible)
    }

    /// Unranked zone: caption + horizontal scroll (fixed height so UIViewControllerRepresentable doesn’t inflate).
    private static let unrankedZoneHeight: CGFloat = 148

    /// App-only: when all items are ranked, show Done button; otherwise unranked list. Extension always shows unranked list.
    private var unrankedZoneSection: some View {
        Group {
            if !isMessageMode && gameLogic.gameState.isComplete {
                appCompleteDoneArea
            } else {
                unrankedZoneContent
                    .modifier(UnrankedZoneVerticalClaimModifier(active: true))
            }
        }
        .frame(height: Self.unrankedZoneHeight)
        .background(GeometryReader { geo in
            Color.clear.preference(key: UnrankedZoneFrameInBoardKey.self, value: geo.frame(in: .named("board")))
        })
    }

    /// App-only: Done button in unranked area when tier list is complete. Tapping renders image and presents share sheet.
    private var appCompleteDoneArea: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Button(action: renderAndShareTierListImage) {
                if isRenderingTierListImage {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Share Tier List")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRenderingTierListImage)
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
        .background(Color.gray.opacity(0.2))
    }

    private func renderAndShareTierListImage() {
        guard !isRenderingTierListImage else { return }
        isRenderingTierListImage = true
        TierListRenderer.renderFinalImage(gameState: gameLogic.gameState) { image in
            DispatchQueue.main.async {
                isRenderingTierListImage = false
                if let image {
                    shareableTierListImage = ShareableTierListImage(image: image)
                }
            }
        }
    }

    private var unrankedZoneContent: some View {
        VStack(spacing: 0) {
            Text("Unranked Items")
                .font(.caption)
                .foregroundColor(.gray)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(gameLogic.gameState.unrankedItems, id: \.id) { item in
                        unrankedItemView(item: item)
                    }
                }
                .padding()
            }
            .frame(height: 120)
        }
        .background(Color.gray.opacity(0.2))
        .contentShape(Rectangle())
        .onTapGesture {
            if isMessageMode { selectedItem = nil }
        }
    }

    private func unrankedItemView(item: Item) -> some View {
        let isSelected = selectedItem?.id == item.id
        let isPointerDragging = usePointerDrag && pointerDragItem?.id == item.id
        return ItemImageView(item: item, gameLogic: gameLogic, isDragged: (draggedItem?.id == item.id) || isPointerDragging, isSelected: isSelected)
            .frame(width: 80, height: 80)
            .opacity(isPointerDragging ? 0 : (canPlace ? 1 : 0.6))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3))
            .background(GeometryReader { geo in
                Color.clear
                    .preference(key: UnrankedItemFramesKey.self, value: [item.id: geo.frame(in: .named("board"))])
                    .preference(key: UnrankedItemGlobalFramesKey.self, value: [item.id: geo.frame(in: .global)])
            })
            .onTapGesture {
                if isMessageMode {
                    if isSelected { selectedItem = nil }
                    else if canPlace { selectedItem = item }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard usePointerDrag else { return }
                        let t = value.translation
                        if pointerDragScrollCancelled { return }
                        // If user dragged down 50pt first, commit to drag and never treat as scroll (e.g. rightmost item dragged toward tiers).
                        if t.height >= Self.verticalDragCommitThreshold {
                            pointerDragCommittedToDrag = true
                        }
                        // Current finger position in global space: gesture location is in the item view's space, so global = item's global frame.origin + value.location.
                        let currentGlobal: CGPoint = {
                            if let frame = unrankedItemGlobalFrames[item.id] {
                                return CGPoint(x: frame.minX + value.location.x, y: frame.minY + value.location.y)
                            }
                            return .zero
                        }()
                        let currentBoard = globalToBoard(currentGlobal)

                        if pointerDragCommittedToDrag {
                            // Already committed to drag; just update (and start drag if not yet).
                            if pointerDragItem != nil {
                                pointerDragTranslation = t
                                pointerDragCurrentBoard = currentBoard
                                hoveredDropTarget = resolveDropTarget(at: currentBoard)
                                return
                            }
                            let distance = sqrt(t.width * t.width + t.height * t.height)
                            if distance >= Self.dragCommitThreshold {
                                pointerDragItem = item
                                pointerDragStartFrame = unrankedItemFrames[item.id]
                                pointerDragStartInGlobal = unrankedItemGlobalFrames[item.id].map { CGPoint(x: $0.midX, y: $0.midY) }
                                pointerDragTranslation = t
                                pointerDragCurrentBoard = currentBoard
                                hoveredDropTarget = resolveDropTarget(at: currentBoard)
                            }
                            return
                        }
                        // Not committed to drag yet: horizontal strictly wins (width > height) past threshold → scroll only.
                        if abs(t.width) >= Self.minScrollDirectionThreshold, abs(t.width) > abs(t.height) {
                            pointerDragScrollCancelled = true
                            clearPointerDrag()
                            return
                        }
                        // Diagonal/short: never start a drag here; only start after vertical commit (above).
                        if pointerDragItem != nil {
                            pointerDragTranslation = t
                            pointerDragCurrentBoard = currentBoard
                            hoveredDropTarget = resolveDropTarget(at: currentBoard)
                            return
                        }
                        // Do not start drag until vertical threshold is met (handled in pointerDragCommittedToDrag block).
                    }
                    .onEnded { value in
                        guard usePointerDrag else { return }
                        if pointerDragItem != nil {
                            let dropBoard: CGPoint = if let frame = unrankedItemGlobalFrames[item.id] {
                                globalToBoard(CGPoint(x: frame.minX + value.location.x, y: frame.minY + value.location.y))
                            } else if let last = pointerDragCurrentBoard {
                                last
                            } else {
                                .zero
                            }
                            resolvePointerDrop(dropPointInBoard: dropBoard)
                        }
                        clearPointerDrag()
                        pointerDragScrollCancelled = false
                        pointerDragCommittedToDrag = false
                    }
            )
            .draggableIf(!usePointerDrag, item.id.uuidString)
    }

    private func placeItem(_ item: Item, inTier tier: Tier) {
        let indexInTier = gameLogic.gameState.items.filter { $0.tier == tier }.count
        placeItem(item, inTier: tier, atIndexInTier: indexInTier)
    }

    private func placeItem(_ item: Item, inTier tier: Tier, atIndexInTier indexInTier: Int) {
        if isMessageMode {
            guard !hasPlacedThisTurn else { return }
            savedOpponentLastPlacedIndex = gameLogic.gameState.lastPlacedItemIndex
            if gameLogic.placeItem(item, inTier: tier, atIndexInTier: indexInTier) {
                hasPlacedThisTurn = true
                lastPlacedItem = item
            }
        } else {
            _ = gameLogic.placeItem(item, inTier: tier, atIndexInTier: indexInTier)
        }
    }

    /// Convert global (screen) point to board coordinate space for overlay and hit-test.
    private func globalToBoard(_ global: CGPoint) -> CGPoint {
        CGPoint(
            x: global.x - boardFrameInGlobal.minX,
            y: global.y - boardFrameInGlobal.minY
        )
    }

    /// Resolve (tier, insertion index) from drop point using tier frames and per-item frames.
    /// Handles both single-row (message mode) and wrapped multi-row (app mode) layouts.
    private func resolveDropTarget(at point: CGPoint) -> (Tier, Int)? {
        guard let (tier, _) = tierFrames.first(where: { $0.value.contains(point) }) else { return nil }
        let frames = tierItemFrames[tier] ?? []
        guard !frames.isEmpty else { return (tier, 0) }

        for (i, frame) in frames.enumerated() {
            let sameRow = abs(frame.midY - point.y) <= frame.height * 0.5
            if sameRow {
                if point.x < frame.midX { return (tier, i) }
                let isLastInRow = i + 1 >= frames.count ||
                    abs(frames[i + 1].midY - frame.midY) > frame.height * 0.5
                if isLastInRow { return (tier, i + 1) }
            } else if frame.midY > point.y {
                return (tier, i)
            }
        }
        return (tier, frames.count)
    }

    private func clearPointerDrag() {
        pointerDragItem = nil
        pointerDragStartFrame = nil
        pointerDragStartInGlobal = nil
        pointerDragCurrentBoard = nil
        pointerDragTranslation = .zero
        hoveredDropTarget = nil
    }

    /// Apply veto: move item to target tier (one step). Called from arrow buttons.
    private func applyVeto(item: Item, from currentTier: Tier, to targetTier: Tier?) {
        guard let target = targetTier, target != currentTier else { return }
        if gameLogic.vetoItem(item, toTier: target) {
            showVetoArrowsForItemID = nil
            lastVetoedFromTier = currentTier
            hasPlacedThisTurn = true
            hasVetoedThisTurn = true
            lastPlacedItem = item
        }
    }

    /// Resolve drop target by hit-testing release point in board space. Place unranked item or move ranked item; drop in unranked zone unranks.
    private func resolvePointerDrop(dropPointInBoard: CGPoint) {
        guard let item = pointerDragItem else { return }
        let isRanked = gameLogic.gameState.items.contains(where: { $0.id == item.id && $0.tier != nil })
        if let (tier, indexInTier) = resolveDropTarget(at: dropPointInBoard) {
            if isRanked {
                _ = gameLogic.moveItem(item, toTier: tier, atIndexInTier: indexInTier)
            } else {
                placeItem(item, inTier: tier, atIndexInTier: indexInTier)
            }
        } else if isRanked, let zone = unrankedZoneFrameInBoard, zone.contains(dropPointInBoard) {
            gameLogic.unrankItemAndMoveToEndOfUnranked(item)
        }
        draggedItem = nil
        hoveredDropTarget = nil
    }

    /// App-only: start pointer drag from a tier item (rearrange). Tier row hides this item's slot via displayedItemsInTier so no phantom.
    private func beginPointerDragFromTier(item: Item) {
        pointerDragItem = item
        pointerDragStartFrame = tierItemFrameByItemId[item.id]
        if let globalFrame = tierItemGlobalFrameByItemId[item.id] {
            pointerDragStartInGlobal = CGPoint(x: globalFrame.midX, y: globalFrame.midY)
        }
        pointerDragCurrentBoard = pointerDragStartFrame.map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// App-only: update pointer drag position when dragging from a tier item.
    private func updatePointerDragFromTier(item: Item, value: DragGesture.Value) {
        guard pointerDragItem?.id == item.id else { return }
        let currentGlobal: CGPoint
        if let frame = tierItemGlobalFrameByItemId[item.id] {
            currentGlobal = CGPoint(x: frame.minX + value.location.x, y: frame.minY + value.location.y)
        } else if let start = pointerDragStartInGlobal {
            currentGlobal = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
        } else {
            currentGlobal = .zero
        }
        pointerDragCurrentBoard = globalToBoard(currentGlobal)
        pointerDragTranslation = value.translation
        hoveredDropTarget = resolveDropTarget(at: pointerDragCurrentBoard ?? .zero)
    }

    /// App-only: end pointer drag from a tier item; place or move at drop point.
    private func endPointerDragFromTier(item: Item, value: DragGesture.Value) {
        guard pointerDragItem?.id == item.id else { return }
        let dropBoard: CGPoint
        if let frame = tierItemGlobalFrameByItemId[item.id] {
            dropBoard = globalToBoard(CGPoint(x: frame.minX + value.location.x, y: frame.minY + value.location.y))
        } else if let start = pointerDragStartInGlobal {
            let endGlobal = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
            dropBoard = globalToBoard(endGlobal)
        } else if let last = pointerDragCurrentBoard {
            dropBoard = last
        } else {
            dropBoard = .zero
        }
        resolvePointerDrop(dropPointInBoard: dropBoard)
        clearPointerDrag()
    }
}

struct ItemImageView: View {
       let item: Item
       let gameLogic: GameLogic
       let isDragged: Bool
       var isSelected: Bool = false

       var body: some View {
           ZStack {
               Color.gray.opacity(0.5)
               if let url = getImageURL(for: item) {
                   AsyncImage(url: url) { phase in
                       switch phase {
                       case .success(let image):
                           image.resizable().scaledToFill()
                       case .empty:
                           ProgressView()
                       default:
                           Color.gray
                       }
                   }
               }
           }
           .cornerRadius(8)
           .opacity(isDragged ? 0.5 : 1.0)
           .shadow(radius: isDragged ? 5 : 0)
       }
                                                                                
       func getImageURL(for item: Item) -> URL? {
           let template = TierTemplate.all.first { $0.name ==
 gameLogic.gameState.templateName }
           return template?.items.first { $0.name == item.name }?.imageURL
       }
   }
                                                                                
   /// App-only: adds drag-from-tier gesture so the parent can track and show overlay.
   private struct TierRowItemDragModifier: ViewModifier {
       let item: Item
       @Binding var tierDragBegunId: UUID?
       var onBegin: ((Item) -> Void)?
       var onChanged: ((Item, DragGesture.Value) -> Void)?
       var onEnded: ((Item, DragGesture.Value) -> Void)?

       private static let commitDistance: CGFloat = 10

       func body(content: Content) -> some View {
           if onBegin != nil {
               content.simultaneousGesture(
                   DragGesture(minimumDistance: 0)
                       .onChanged { value in
                           let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                           if tierDragBegunId == nil, distance >= Self.commitDistance {
                               onBegin?(item)
                               tierDragBegunId = item.id
                           }
                           if tierDragBegunId == item.id {
                               onChanged?(item, value)
                           }
                       }
                       .onEnded { value in
                           if tierDragBegunId == item.id {
                               onEnded?(item, value)
                               tierDragBegunId = nil
                           }
                       }
               )
           } else {
               content
           }
       }
   }

   struct TierRowView: View {
       let tier: Tier
       @ObservedObject var gameLogic: GameLogic
       let draggedItem: Item?
       /// When non-nil, this item is being pointer-dragged (from unranked or from a tier).
       var pointerDragItem: Item? = nil
       /// When false (app only), horizontal scroll in this tier row is disabled.
       var tierRowScrollEnabled: Bool = true
       @Binding var hoveredTier: Tier?
       /// When dragging, index in this tier where the item would be inserted; show placeholder here.
       var insertionIndexInTier: Int?
       var selectedItem: Item?
       var lastPlacedItemID: UUID?
       var opponentLastPlacedItemID: UUID?
       var canVeto: Bool
       var showVetoArrowsForItemID: UUID?
       var onTapPurpleItem: ((Item) -> Void)?
       var onVetoMoveUp: ((Item) -> Void)?
       var onVetoMoveDown: ((Item) -> Void)?
       var onDrop: (Item) -> Void
       var onTapTier: (() -> Void)?
       var onTapItemToUnrank: ((Item) -> Void)?
       /// App-only: drag from tier to rearrange. Callbacks for pointer-drag lifecycle.
       var onBeginDragFromTier: ((Item) -> Void)? = nil
       var onDragTierItemChanged: ((Item, DragGesture.Value) -> Void)? = nil
       var onDragTierItemEnded: ((Item, DragGesture.Value) -> Void)? = nil

       @State private var tierDragBegunId: UUID?

       private var itemsInTier: [Item] {
           gameLogic.gameState.items.filter { $0.tier == tier }
       }

       var tierColor: Color {
           switch tier {
           case .S: return Color(red: 1.0, green: 0.2, blue: 0.2)
           case .A: return Color(red: 1.0, green: 0.6, blue: 0.2)
           case .B: return Color(red: 1.0, green: 1.0, blue: 0.2)
           case .C: return Color(red: 0.2, green: 1.0, blue: 0.2)
           case .D: return Color(red: 0.2, green: 0.8, blue: 1.0)
           case .T: return Color(red: 0, green: 0, blue: 0)
           }
       }

       private var insertionPlaceholder: some View {
           RoundedRectangle(cornerRadius: 8)
               .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
               .foregroundColor(.white.opacity(0.9))
               .frame(width: 70, height: 70)
       }

       private var tierRowScrollContent: some View {
           HStack(spacing: 8) {
               ForEach(Array(itemsInTier.enumerated()), id: \.element.id) { index, item in
                   if insertionIndexInTier == index {
                       insertionPlaceholder
                   }
                   tierRowItemView(item: item)
               }
               if insertionIndexInTier == itemsInTier.count {
                   insertionPlaceholder
               }
           }
           .padding()
           .padding(.trailing, itemsInTier.count >= 2 ? 80 : 0)
       }

       private var tierRowWrappedContent: some View {
           FlowLayout(spacing: 8) {
               ForEach(Array(itemsInTier.enumerated()), id: \.element.id) { index, item in
                   if insertionIndexInTier == index {
                       insertionPlaceholder
                   }
                   tierRowItemView(item: item)
               }
               if insertionIndexInTier == itemsInTier.count {
                   insertionPlaceholder
               }
           }
           .padding(8)
           .frame(maxWidth: .infinity, alignment: .leading)
       }

       private func tierRowItemView(item: Item) -> some View {
           let canUnrankByTap = lastPlacedItemID == item.id && onTapItemToUnrank != nil
           let isOpponentLastPlaced = opponentLastPlacedItemID == item.id
           let arrowsVisible = showVetoArrowsForItemID == item.id
           let isDragged = (draggedItem?.id == item.id) || (pointerDragItem?.id == item.id)
           let isPointerDraggingThisItem = pointerDragItem?.id == item.id
           return ItemImageView(item: item, gameLogic: gameLogic, isDragged: isDragged)
               .opacity(isPointerDraggingThisItem ? 0 : 1)
               .frame(width: 70, height: 70)
               .background(GeometryReader { geo in
                   Color.clear
                       .preference(key: TierItemFramesKey.self, value: [TierItemFrameEntry(tier: tier, itemId: item.id, frame: geo.frame(in: .named("board")))])
                       .preference(key: TierItemGlobalFramesKey.self, value: [TierItemGlobalFrameEntry(itemId: item.id, frame: geo.frame(in: .global))])
               })
               .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                   canUnrankByTap ? Color.orange : (isOpponentLastPlaced ? Color.purple : Color.clear),
                   lineWidth: 2
               ))
               .overlay {
                   if canUnrankByTap {
                       Color.clear
                           .contentShape(Rectangle())
                           .highPriorityGesture(
                               TapGesture().onEnded { _ in onTapItemToUnrank?(item) }
                           )
                   }
               }
               .overlay {
                   if isOpponentLastPlaced && canVeto, let onTapPurple = onTapPurpleItem, !arrowsVisible {
                       Color.clear
                           .contentShape(Rectangle())
                           .highPriorityGesture(TapGesture().onEnded { _ in onTapPurple(item) })
                   }
               }
               .overlay {
                   if arrowsVisible {
                       tierRowVetoArrows(item: item)
                   }
               }
               .modifier(TierRowItemDragModifier(
                   item: item,
                   tierDragBegunId: $tierDragBegunId,
                   onBegin: onBeginDragFromTier,
                   onChanged: onDragTierItemChanged,
                   onEnded: onDragTierItemEnded
               ))
       }

       private func tierRowVetoArrows(item: Item) -> some View {
           VStack {
               if tier.tierAbove != nil, let onUp = onVetoMoveUp {
                   Button(action: { onUp(item) }) {
                       ZStack {
                           Circle().fill(.white)
                           Image(systemName: "arrow.up")
                               .font(.system(size: 14, weight: .semibold))
                               .foregroundColor(.black)
                       }
                       .frame(width: 28, height: 28)
                   }
                   .buttonStyle(.plain)
                   .padding(.top, 2)
               }
               Spacer(minLength: 0)
               if tier.tierBelow != nil, let onDown = onVetoMoveDown {
                   Button(action: { onDown(item) }) {
                       ZStack {
                           Circle().fill(.white)
                           Image(systemName: "arrow.down")
                               .font(.system(size: 14, weight: .semibold))
                               .foregroundColor(.black)
                       }
                       .frame(width: 28, height: 28)
                   }
                   .buttonStyle(.plain)
                   .padding(.bottom, 2)
               }
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity)
           .allowsHitTesting(true)
       }

       var body: some View {
           HStack(spacing: 0) {
               Text(tier.displayName)
                   .font(.system(size: 32, weight: .bold))
                   .frame(width: 60)
                   .frame(maxHeight: .infinity)
                   .foregroundColor(.black)
                   .contentShape(Rectangle())
                   .onTapGesture { onTapTier?() }
               if tierRowScrollEnabled {
                   ScrollView(.horizontal) {
                       tierRowScrollContent
                   }
               } else {
                   tierRowWrappedContent
               }
           }
           .background(tierColor)
           .dropDestination(for: String.self) { dropped, _ in
               if let itemIDString = dropped.first,
                  let itemID = UUID(uuidString: itemIDString),
                  let item = gameLogic.gameState.items.first(where: { $0.id == itemID }) {
                   onDrop(item)
                   return true
               }
               return false
           } isTargeted: { isTargeted in
               if isTargeted {
                   hoveredTier = tier
               } else if hoveredTier == tier {
                   hoveredTier = nil
               }
           }
       }
   }

// MARK: - Message extension: separate top bar (drag to minimize) vs content (drag = scroll/item)

private struct MessageExtensionTopBar: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Spacer(minLength: 0)
                .frame(height: 4)
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

/// In message mode, claims pan gestures in the content area so the system "drag to minimize" only applies to the top bar.
/// Uses minimumDistance so a quick tap is not claimed and can reach tier-row tap-to-unrank.
private struct ClaimDragInMessageExtensionModifier: ViewModifier {
    var active: Bool
    private static let claimDragMinimumDistance: CGFloat = 12
    func body(content: Content) -> some View {
        if active {
            content.highPriorityGesture(
                DragGesture(minimumDistance: Self.claimDragMinimumDistance)
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
        } else {
            content
        }
    }
}

// MARK: - Vertical-only claim (unranked zone: diagonal constraint so gesture is either scroll OR drag, never both)

private final class VerticalOnlyPanGestureRecognizer: UIPanGestureRecognizer {
    /// Minimum movement before we decide; scroll when dx > dy, drag when dy > dx.
    /// Match GameBoardView: vertical past this → drag only.
    private static let verticalDragCommitThreshold: CGFloat = 50
    /// Minimum movement before we can decide vertical-dominant drag (so we don’t claim tiny moves).
    private static let minDirectionThreshold: CGFloat = 15
    private var initialTouch: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        initialTouch = touches.first?.location(in: view)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible, let touch = touches.first, let start = initialTouch else {
            super.touchesMoved(touches, with: event)
            return
        }
        let current = touch.location(in: view)
        let dx = abs(current.x - start.x)
        let dy = abs(current.y - start.y)
        // Force one state: scroll when horizontal strictly wins (dx > dy) past min threshold; drag when vertical wins; else stay possible.
        if dx >= Self.minDirectionThreshold && dx > dy {
            state = .failed
            return
        }
        if dy >= Self.verticalDragCommitThreshold || (dy >= Self.minDirectionThreshold && dy > dx) {
            state = .began
            return
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        initialTouch = nil
        super.reset()
    }
}

/// Find first UIScrollView in the view hierarchy (SwiftUI ScrollView backs to one).
private func findScrollView(in view: UIView) -> UIScrollView? {
    if let sv = view as? UIScrollView { return sv }
    for subview in view.subviews {
        if let found = findScrollView(in: subview) { return found }
    }
    return nil
}

/// Walk up the superview chain to find the nearest UIScrollView ancestor.
private func findParentScrollView(of view: UIView) -> UIScrollView? {
    var current: UIView? = view.superview
    while let v = current {
        if let sv = v as? UIScrollView { return sv }
        current = v.superview
    }
    return nil
}

/// Placed as a background inside a ScrollView; finds the backing UIScrollView and
/// sets `minimumNumberOfTouches = 2` so single-finger gestures are reserved for item drag.
private struct TwoFingerScrollPatcher: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        context.coordinator.patchTarget = view
        context.coordinator.patchIfNeeded()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.patchIfNeeded()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var patchTarget: UIView?
        private var patched = false

        func patchIfNeeded() {
            guard !patched, let view = patchTarget else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.patched, let target = self.patchTarget else { return }
                if let scrollView = findParentScrollView(of: target) {
                    scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
                    self.patched = true
                }
            }
        }
    }
}

private struct UnrankedZoneVerticalClaimWrapper<Content: View>: UIViewControllerRepresentable {
    let content: Content
    var active: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIHostingController(rootView: content)
        context.coordinator.host = host
        let pan = VerticalOnlyPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.cancelsTouchesInView = false
        host.view.addGestureRecognizer(pan)
        context.coordinator.panRecognizer = pan
        context.coordinator.installScrollViewDependency()
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.host?.rootView = content
        context.coordinator.panRecognizer?.isEnabled = active
        context.coordinator.installScrollViewDependency()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var host: UIHostingController<Content>?
        var panRecognizer: VerticalOnlyPanGestureRecognizer?
        /// So we only add the dependency once per scroll view.
        private var scrollViewDependencyInstalled = false

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {}

        /// Make the unranked ScrollView's pan require our recognizer to fail. When we claim the gesture (vertical drag), scroll view then won't recognize and steal horizontal movement.
        func installScrollViewDependency() {
            guard let hostView = host?.view,
                  let ourPan = panRecognizer,
                  !scrollViewDependencyInstalled else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.scrollViewDependencyInstalled else { return }
                guard let scrollView = findScrollView(in: hostView) else { return }
                scrollView.panGestureRecognizer.require(toFail: ourPan)
                self.scrollViewDependencyInstalled = true
            }
        }
    }
}

private struct UnrankedZoneVerticalClaimModifier: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        if active {
            UnrankedZoneVerticalClaimWrapper(content: content, active: true)
        } else {
            content
        }
    }
}

// MARK: - Share tier list image (app only)

/// Custom activity so "Save to Photos" is always available in the share sheet.
private final class SaveToPhotosActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.sethchun.TierMaker.saveToPhotos")
    }

    override var activityTitle: String? { "Save to Photos" }
    override var activityImage: UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "square.and.arrow.down")
        }
        return nil
    }

    private var imageToSave: UIImage?

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is UIImage }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        imageToSave = activityItems.compactMap { $0 as? UIImage }.first
    }

    override func perform() {
        guard let image = imageToSave else {
            activityDidFinish(false)
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer?) {
        activityDidFinish(error == nil)
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [image],
            applicationActivities: [SaveToPhotosActivity()]
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Flow layout for wrapping tier items (app mode)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Conditional modifiers for gesture vs system DnD

private extension View {
    @ViewBuilder
    func draggableIf(_ condition: Bool, _ payload: String) -> some View {
        if condition {
            self.draggable(payload)
        } else {
            self
        }
    }
}
