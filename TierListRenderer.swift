import UIKit

// MARK: - Layout constants for final (script-style) image
private let finalItemSize: CGFloat = 80
private let finalTierLabelWidth: CGFloat = 40
private let finalItemSpacing: CGFloat = 0
private let finalTierLabelFontSize: CGFloat = 36 * 0.8
private let finalMaxItemsPerRow: Int = 8

class TierListRenderer {
    let gameState: GameState
    let tierColors: [Tier: UIColor] = [
        .S: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),    // Red
        .A: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),    // Orange
        .B: UIColor(red: 1.0, green: 1.0, blue: 0.2, alpha: 1.0),    // Yellow
        .C: UIColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 1.0),    // Green
        .D: UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0)     // Blue
    ]
    
    init(gameState: GameState) {
        self.gameState = gameState
    }
    
    /// Renders the script-style final tier list (tier labels + black item area, images only, S at top). Loads images from template URLs; calls completion on main.
    static func renderFinalImage(gameState: GameState, completion: @escaping (UIImage?) -> Void) {
        guard gameState.isComplete,
              let template = TierTemplate.all.first(where: { $0.name == gameState.templateName }) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let displayTiers = Tier.displayTiers
        let itemsByTier: [Tier: [Item]] = displayTiers.reduce(into: [:]) { result, tier in
            result[tier] = gameState.items.filter { $0.tier == tier }
        }
        // Build display rows: wrap at 15 items per row; only first row of each tier shows the tier letter
        struct DisplayRow {
            let tier: Tier
            let showLabel: Bool
            let itemCount: Int
        }
        var displayRows: [DisplayRow] = []
        for tier in displayTiers {
            let items = itemsByTier[tier] ?? []
            var remaining = items.count
            var isFirst = true
            repeat {
                let count = min(finalMaxItemsPerRow, remaining)
                displayRows.append(DisplayRow(tier: tier, showLabel: isFirst, itemCount: count))
                remaining -= count
                isFirst = false
            } while remaining > 0
        }
        let rowHeight = finalItemSize
        func rowWidth(itemCount: Int) -> CGFloat {
            guard itemCount > 0 else { return finalTierLabelWidth }
            return finalTierLabelWidth + CGFloat(itemCount) * finalItemSize + CGFloat(max(0, itemCount - 1)) * finalItemSpacing
        }
        let maxRowWidth = displayRows.map { rowWidth(itemCount: $0.itemCount) }.max() ?? finalTierLabelWidth
        let imageWidth = maxRowWidth
        let imageHeight = CGFloat(displayRows.count) * rowHeight
        let scale: CGFloat = 2
        let w = Int(imageWidth * scale)
        let h = Int(imageHeight * scale)
        guard w > 0, h > 0 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // Collect image URLs by item name (template order per tier)
        var urlsToLoad: [URL] = []
        for tier in displayTiers {
            for item in itemsByTier[tier] ?? [] {
                if let templateItem = template.items.first(where: { $0.name == item.name }) {
                    urlsToLoad.append(templateItem.imageURL)
                }
            }
        }
        loadImages(urls: urlsToLoad) { images in
            guard images.count == urlsToLoad.count else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            var imageIndex = 0
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(w), height: CGFloat(h)))
            let image = renderer.image { context in
                let ctx = context.cgContext
                ctx.scaleBy(x: scale, y: scale)
                // UIKit: y increases down, so S at top = row 0 at y=0
                for (rowIndex, displayRow) in displayRows.enumerated() {
                    let y = CGFloat(rowIndex) * rowHeight
                    let tier = displayRow.tier
                    let tierLabelRect = CGRect(x: 0, y: y, width: finalTierLabelWidth, height: rowHeight)
                    let itemAreaRect = CGRect(x: finalTierLabelWidth, y: y, width: max(0, imageWidth - finalTierLabelWidth), height: rowHeight)
                    tierColors[tier]?.setFill()
                    ctx.fill(tierLabelRect)
                    if displayRow.showLabel {
                        drawFinalTierLetter(tier.displayName, in: tierLabelRect, context: ctx)
                    }
                    UIColor.black.setFill()
                    ctx.fill(itemAreaRect)
                    var x = finalTierLabelWidth
                    for _ in 0..<displayRow.itemCount {
                        if imageIndex < images.count, let img = images[imageIndex].cgImage {
                            let itemRect = CGRect(x: x, y: y, width: finalItemSize, height: finalItemSize)
                            drawImageCorrectlyOriented(img, in: itemRect, context: ctx)
                        }
                        imageIndex += 1
                        x += finalItemSize + finalItemSpacing
                    }
                }
            }
            DispatchQueue.main.async { completion(image) }
        }
    }
    
    private static let tierColors: [Tier: UIColor] = [
        .S: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),
        .A: UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
        .B: UIColor(red: 1.0, green: 1.0, blue: 0.2, alpha: 1.0),
        .C: UIColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 1.0),
        .D: UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0)
    ]
    
    /// Draw CGImage with vertical flip only (context is top-left origin; CGImage is bottom-left).
    private static func drawImageCorrectlyOriented(_ cgImage: CGImage, in rect: CGRect, context ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    private static func drawFinalTierLetter(_ letter: String, in rect: CGRect, context ctx: CGContext) {
        let font = UIFont.boldSystemFont(ofSize: finalTierLabelFontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let str = letter as NSString
        let size = str.size(withAttributes: attrs)
        let drawRect = CGRect(x: rect.minX + (rect.width - size.width) / 2, y: rect.minY + (rect.height - size.height) / 2, width: rect.width, height: size.height)
        str.draw(in: drawRect, withAttributes: attrs)
    }
    
    private static func loadImages(urls: [URL], completion: @escaping ([UIImage]) -> Void) {
        guard !urls.isEmpty else {
            completion([])
            return
        }
        var results: [UIImage?] = Array(repeating: nil, count: urls.count)
        let group = DispatchGroup()
        for (index, url) in urls.enumerated() {
            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                if let data = data, let image = UIImage(data: data) {
                    results[index] = image
                }
            }.resume()
        }
        group.notify(queue: .global(qos: .userInitiated)) {
            let loaded = results.compactMap { $0 }
            completion(loaded.count == urls.count ? loaded : []) // preserve order; only succeed if all loaded
        }
    }
    
    /// Renders the in-progress message preview using item images (from template imageURL). Calls completion on main.
    static func renderPreviewImage(gameState: GameState, size: CGSize = CGSize(width: 800, height: 600), completion: @escaping (UIImage?) -> Void) {
        guard let template = TierTemplate.all.first(where: { $0.name == gameState.templateName }) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let tierLabels = Tier.displayTiers
        var urlsToLoad: [URL] = []
        for tier in tierLabels {
            let itemsInTier = gameState.items.filter { $0.tier == tier }
            for item in itemsInTier {
                if let templateItem = template.items.first(where: { $0.name == item.name }) {
                    urlsToLoad.append(templateItem.imageURL)
                }
            }
        }
        loadImages(urls: urlsToLoad) { images in
            guard images.count == urlsToLoad.count else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            var imageIndex = 0
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.darkGray.setFill()
                context.cgContext.fill(CGRect(origin: .zero, size: size))

                let topOffset: CGFloat = 20
                let titleRect = CGRect(x: 0, y: topOffset, width: size.width, height: 40)
                drawTextStatic(
                    gameState.templateName,
                    in: titleRect,
                    fontSize: 24,
                    color: .white,
                    alignment: .center
                )

                let contentTop = topOffset + 40
                let rowHeight = (size.height - contentTop - 20) / CGFloat(tierLabels.count)
                let tierLabelWidth: CGFloat = 60
                let contentX = tierLabelWidth + 20
                let contentWidth = size.width - contentX - 20
                let previewItemSize: CGFloat = rowHeight - 8
                let previewSpacing: CGFloat = 6

                for (index, tier) in tierLabels.enumerated() {
                    let y = contentTop + CGFloat(index) * rowHeight
                    let rowRect = CGRect(x: 0, y: y, width: size.width, height: rowHeight)

                    TierListRenderer.tierColors[tier]?.setFill()
                    context.cgContext.fill(rowRect)

                    let labelRect = CGRect(x: 10, y: y, width: tierLabelWidth, height: rowHeight)
                    drawTextStatic(
                        tier.displayName,
                        in: labelRect,
                        fontSize: 32,
                        color: .black,
                        alignment: .center
                    )

                    let itemsInTier = gameState.items.filter { $0.tier == tier }
                    var x = contentX
                    let itemY = y + (rowHeight - previewItemSize) / 2
                    for _ in itemsInTier {
                        if imageIndex < images.count, let cgImage = images[imageIndex].cgImage {
                            let itemRect = CGRect(x: x, y: itemY, width: previewItemSize, height: previewItemSize)
                            drawImageCorrectlyOriented(cgImage, in: itemRect, context: context.cgContext)
                        }
                        imageIndex += 1
                        x += previewItemSize + previewSpacing
                    }
                }
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private static func drawTextStatic(
        _ text: String,
        in rect: CGRect,
        fontSize: CGFloat,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let drawRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - boundingRect.height) / 2,
            width: rect.width,
            height: boundingRect.height
        )
        attributedString.draw(in: drawRect)
    }

    func renderImage(size: CGSize = CGSize(width: 800, height: 600)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let isComplete = gameState.isComplete

        let image = renderer.image { context in
            // Background (slightly different when complete)
            if isComplete {
                UIColor(red: 0.15, green: 0.2, blue: 0.25, alpha: 1.0).setFill()
            } else {
                UIColor.darkGray.setFill()
            }
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            var topOffset: CGFloat = 20

            // Final ranking banner when complete
            if isComplete {
                let bannerHeight: CGFloat = 44
                let bannerRect = CGRect(x: 0, y: 0, width: size.width, height: bannerHeight)
                UIColor(red: 0.2, green: 0.6, blue: 0.35, alpha: 1.0).setFill()
                context.cgContext.fill(bannerRect)
                drawText(
                    "✓ Final ranking",
                    in: bannerRect,
                    fontSize: 22,
                    color: .white,
                    alignment: .center
                )
                topOffset = bannerHeight + 8
            }

            // Title
            let titleRect = CGRect(x: 0, y: topOffset, width: size.width, height: 40)
            drawText(
                gameState.templateName,
                in: titleRect,
                fontSize: 24,
                color: .white,
                alignment: .center
            )

            // Tier rows (exclude trash tier)
            let tierLabels = Tier.displayTiers
            let contentTop = topOffset + 40
            let rowHeight = (size.height - contentTop - 20) / CGFloat(tierLabels.count)
            let tierLabelWidth: CGFloat = 60
            let contentX = tierLabelWidth + 20
            let contentWidth = size.width - contentX - 20

            for (index, tier) in tierLabels.enumerated() {
                let y = contentTop + CGFloat(index) * rowHeight
                let rowRect = CGRect(x: 0, y: y, width: size.width, height: rowHeight)

                // Tier background
                tierColors[tier]?.setFill()
                context.cgContext.fill(rowRect)

                // Tier label
                let labelRect = CGRect(x: 10, y: y, width: tierLabelWidth, height: rowHeight)
                drawText(
                    tier.displayName,
                    in: labelRect,
                    fontSize: 32,
                    color: .black,
                    alignment: .center
                )

                // Items in this tier
                let itemsInTier = gameState.items.filter { $0.tier == tier }
                let itemTexts = itemsInTier.map { $0.name }.joined(separator: ", ")

                let contentRect = CGRect(x: contentX, y: y, width: contentWidth, height: rowHeight)
                drawText(
                    itemTexts,
                    in: contentRect,
                    fontSize: 14,
                    color: .white,
                    alignment: .left
                )
            }

            // Optional: completion border when complete
            if isComplete {
                context.cgContext.setStrokeColor(UIColor(red: 0.2, green: 0.6, blue: 0.35, alpha: 1.0).cgColor)
                context.cgContext.setLineWidth(6)
                context.cgContext.stroke(CGRect(x: 3, y: 3, width: size.width - 6, height: size.height - 6))
            }
        }

        return image
    }
    
    private func drawText(
        _ text: String,
        in rect: CGRect,
        fontSize: CGFloat,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let drawRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - boundingRect.height) / 2,
            width: rect.width,
            height: boundingRect.height
        )
        
        attributedString.draw(in: drawRect)
    }
}
