import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preference keys for customize view

private struct CustomizeItemFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, n in n }
    }
}

private struct TrashFrameKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

/// Container (main VStack) frame in global space so we can convert drop point for overlay positioning.
private struct CustomizeContainerFrameKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

// MARK: - Vertical-only claim (same as tier list: claim vertical drags so horizontal = scroll)

private final class CustomizeVerticalOnlyPanGestureRecognizer: UIPanGestureRecognizer {
    private static let directionThreshold: CGFloat = 15
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
        if dx >= Self.directionThreshold || dy >= Self.directionThreshold {
            if dx >= dy {
                state = .failed
                return
            }
            state = .began
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        initialTouch = nil
        super.reset()
    }
}

private struct CustomizeVerticalClaimWrapper<Content: View>: UIViewControllerRepresentable {
    let content: Content
    var active: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIHostingController(rootView: content)
        context.coordinator.host = host
        let pan = CustomizeVerticalOnlyPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.cancelsTouchesInView = false
        host.view.addGestureRecognizer(pan)
        context.coordinator.panRecognizer = pan
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.host?.rootView = content
        context.coordinator.panRecognizer?.isEnabled = active
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var host: UIHostingController<Content>?
        var panRecognizer: CustomizeVerticalOnlyPanGestureRecognizer?
        @objc func pan(_ recognizer: UIPanGestureRecognizer) {}
    }
}

private struct CustomizeVerticalClaimModifier: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        if active {
            CustomizeVerticalClaimWrapper(content: content, active: true)
        } else {
            content
        }
    }
}

// MARK: - CategoryCustomizeView

/// Shown after picking a category. User sees all items in a horizontal scroll (like the tier list unranked zone),
/// can drag items to a trash "tier" to exclude them from the round, then tap Done to start the game.
struct CategoryCustomizeView: View {
    let template: TierTemplate
    var onDone: (Set<String>) -> Void

    /// Ordered so we can show trashed items and undo the last one.
    @State private var trashedNames: [String] = []

    /// Pointer-style drag (tap and drag, same as tier list)
    @State private var pointerDragItem: TierTemplate.TemplateItem?
    @State private var pointerDragStartFrame: CGRect?
    @State private var pointerDragTranslation: CGSize = .zero
    @State private var pointerDragScrollCancelled = false
    @State private var pointerDragCommittedToDrag = false
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var trashFrame: CGRect?
    @State private var containerFrameInGlobal: CGRect?

    private var availableItems: [TierTemplate.TemplateItem] {
        let set = Set(trashedNames)
        return template.items.filter { !set.contains($0.name) }
    }

    private var trashedItems: [TierTemplate.TemplateItem] {
        trashedNames.compactMap { name in template.items.first { $0.name == name } }
    }

    /// True when dragging an item and the current drop point is over the trash zone.
    private var isTrashDropTarget: Bool {
        guard pointerDragItem != nil, let start = pointerDragStartFrame, let frame = trashFrame else { return false }
        let dropPoint = CGPoint(
            x: start.midX + pointerDragTranslation.width,
            y: start.midY + pointerDragTranslation.height
        )
        return frame.contains(dropPoint)
    }

    private static let itemSize: CGFloat = 80
    private static let gridSpacing: CGFloat = 12
    private static let rowsPerColumn: Int = 3
    /// Match tier list unranked zone: once user moves down this much, treat as drag and never cancel.
    private static let verticalDragCommitThreshold: CGFloat = 50
    /// Horizontal-first (before commit) = scroll; after commit we ignore horizontal and keep drag.
    private static let horizontalScrollThreshold: CGFloat = 20
    private static let dragCommitThreshold: CGFloat = 10
    /// No offset: drag preview and drop hit-test use item center + translation (1:1, same as tier list without offset).

    /// Chunk items into columns of 3 rows; columns extend horizontally.
    private var itemColumns: [[TierTemplate.TemplateItem]] {
        stride(from: 0, to: availableItems.count, by: Self.rowsPerColumn).map {
            Array(availableItems[$0 ..< min($0 + Self.rowsPerColumn, availableItems.count)])
        }
    }

    private static var itemsSectionScrollHeight: CGFloat {
        CGFloat(rowsPerColumn) * (Self.itemSize + Self.gridSpacing) + Self.gridSpacing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: category name + horizontal scroll (items stacked vertically per column, extends horizontally)
            VStack(spacing: 0) {
                Text(template.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                if availableItems.isEmpty {
                    Text("Include at least one item to start.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }
                Text("Drag items to trash to exclude from the round")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: Self.gridSpacing) {
                        ForEach(Array(itemColumns.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: Self.gridSpacing) {
                                ForEach(column, id: \.name) { templateItem in
                                    templateItemCard(templateItem)
                                }
                            }
                        }
                    }
                    .padding(Self.gridSpacing)
                }
                .frame(height: Self.itemsSectionScrollHeight)
            }
            .frame(height: Self.itemsSectionScrollHeight + 60)
            .background(Color.gray.opacity(0.2))
            .contentShape(Rectangle())
            .modifier(CustomizeVerticalClaimModifier(active: true))
            .onPreferenceChange(CustomizeItemFramesKey.self) { itemFrames = $0 }

            // Middle: trash tier
            trashZone(highlightAsDropTarget: isTrashDropTarget)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: TrashFrameKey.self, value: geo.frame(in: .global))
                })

            Spacer(minLength: 0)

            // Bottom: Done button (padding above = space from trash, below = space from screen edge)
            Button(action: { onDone(Set(trashedNames)) }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(availableItems.isEmpty)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GeometryReader { geo in
            Color.clear.preference(key: CustomizeContainerFrameKey.self, value: geo.frame(in: .global))
        })
        .onPreferenceChange(TrashFrameKey.self) { trashFrame = $0 }
        .onPreferenceChange(CustomizeContainerFrameKey.self) { containerFrameInGlobal = $0 }
        .overlay {
            if let item = pointerDragItem, let start = pointerDragStartFrame, let container = containerFrameInGlobal {
                let dropXGlobal = start.midX + pointerDragTranslation.width
                let dropYGlobal = start.midY + pointerDragTranslation.height
                let x = dropXGlobal - container.minX
                let y = dropYGlobal - container.minY
                templateItemImage(item)
                    .frame(width: Self.itemSize, height: Self.itemSize)
                    .shadow(radius: 8)
                    .position(x: x, y: y)
                    .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func templateItemCard(_ templateItem: TierTemplate.TemplateItem) -> some View {
        let isPointerDragging = pointerDragItem?.name == templateItem.name
        return templateItemImage(templateItem)
            .frame(width: Self.itemSize, height: Self.itemSize)
            .opacity(isPointerDragging ? 0.5 : 1)
            .shadow(radius: isPointerDragging ? 5 : 0)
            .background(GeometryReader { geo in
                Color.clear.preference(key: CustomizeItemFramesKey.self, value: [templateItem.name: geo.frame(in: .global)])
            })
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let t = value.translation
                        if pointerDragScrollCancelled { return }
                        // Once we've moved down 50pt, we're committed to drag — never cancel for horizontal (match tier list)
                        if pointerDragCommittedToDrag {
                            if pointerDragItem != nil {
                                pointerDragTranslation = t
                                return
                            }
                            let distance = sqrt(t.width * t.width + t.height * t.height)
                            if distance >= Self.dragCommitThreshold {
                                pointerDragItem = templateItem
                                pointerDragStartFrame = itemFrames[templateItem.name]
                                pointerDragTranslation = t
                            }
                            return
                        }
                        // Not committed yet: horizontal-first = scroll (cancel drag)
                        if abs(t.width) >= Self.horizontalScrollThreshold, abs(t.width) >= abs(t.height) {
                            pointerDragScrollCancelled = true
                            clearPointerDrag()
                            return
                        }
                        // Moved down 50pt = commit to drag; they can then move left/right freely (match tier list)
                        if t.height >= Self.verticalDragCommitThreshold {
                            pointerDragCommittedToDrag = true
                        }
                        if pointerDragItem != nil {
                            pointerDragTranslation = t
                            return
                        }
                        let distance = sqrt(t.width * t.width + t.height * t.height)
                        if distance >= Self.dragCommitThreshold {
                            pointerDragItem = templateItem
                            pointerDragStartFrame = itemFrames[templateItem.name]
                            pointerDragTranslation = t
                        }
                    }
                    .onEnded { value in
                        if pointerDragItem != nil {
                            resolvePointerDrop(translation: value.translation)
                        }
                        clearPointerDrag()
                        pointerDragScrollCancelled = false
                        pointerDragCommittedToDrag = false
                    }
            )
    }

    private func templateItemImage(_ templateItem: TierTemplate.TemplateItem) -> some View {
        ZStack {
            Color.gray.opacity(0.5)
            AsyncImage(url: templateItem.imageURL) { phase in
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
        .cornerRadius(8)
    }

    private func clearPointerDrag() {
        pointerDragItem = nil
        pointerDragStartFrame = nil
        pointerDragTranslation = .zero
    }

    private func resolvePointerDrop(translation: CGSize) {
        guard let item = pointerDragItem, let start = pointerDragStartFrame else { return }
        let dropPoint = CGPoint(
            x: start.midX + translation.width,
            y: start.midY + translation.height
        )
        if let frame = trashFrame, frame.contains(dropPoint) {
            trashedNames.append(item.name)
        }
    }

    private static let trashTierColor = Color(red: 0.35, green: 0.22, blue: 0.22)
    private static let trashTierHeight: CGFloat = 88
    private static let trashThumbSize: CGFloat = 56

    private func trashZone(highlightAsDropTarget: Bool) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "trash.fill")
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 60)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trashedItems, id: \.name) { templateItem in
                        let isLast = trashedNames.last == templateItem.name
                        trashItemThumb(templateItem, isLast: isLast)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, (Self.trashTierHeight - Self.trashThumbSize) / 2)
            }
            if !trashedNames.isEmpty {
                Button(action: undoLastTrashed) {
                    Text("Undo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.trashTierHeight)
        .background(Self.trashTierColor)
        .overlay {
            if highlightAsDropTarget {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.red, lineWidth: 4)
                    .background(Color.red.opacity(0.35))
            }
        }
        .contentShape(Rectangle())
    }

    private func trashItemThumb(_ templateItem: TierTemplate.TemplateItem, isLast: Bool) -> some View {
        templateItemImage(templateItem)
            .frame(width: Self.trashThumbSize, height: Self.trashThumbSize)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isLast ? Color.orange : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture {
                if isLast {
                    undoLastTrashed()
                }
            }
    }

    private func undoLastTrashed() {
        guard !trashedNames.isEmpty else { return }
        trashedNames.removeLast()
    }
}
