import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Tier colors (match app GameBoardView / TierListRenderer)

private let tierColors: [Tier: (r: CGFloat, g: CGFloat, b: CGFloat)] = [
    .S: (1.0, 0.2, 0.2),
    .A: (1.0, 0.6, 0.2),
    .B: (1.0, 1.0, 0.2),
    .C: (0.2, 1.0, 0.2),
    .D: (0.2, 0.8, 1.0)
]

// MARK: - Layout constants

/// Row height = drawn item height (so tier row is same as tallest image in the row).
private let itemSize: CGFloat = 80
private let tierLabelWidth: CGFloat = 40
private let itemSpacing: CGFloat = 0
private let tierLabelFontSize: CGFloat = 36 * 0.8  // 80% of original

// MARK: - Render

/// Renders the tier list image: width = largest tier row width, height = S–D rows stacked. No title/border; tier letter with tier color; item area black; images in URL order.
func renderTierListImage(state: DecodedState, template: Template) -> CGImage? {
    guard state.templateIndex >= 0, state.templateIndex < Template.all.count,
          template.items.count == state.tiers.count else { return nil }

    // Group ranked items by tier. If state.order is present, use it (placement order); else template index order.
    typealias ItemIndex = Int
    var itemsByTier: [Tier: [ItemIndex]] = [:]
    let sourceOrder: [Int]
    if let ord = state.order, ord.count == state.tiers.count {
        sourceOrder = ord
    } else {
        sourceOrder = Array(0..<state.tiers.count)
    }
    let displayTiers = Tier.displayTiers
    for tier in displayTiers {
        itemsByTier[tier] = sourceOrder.filter { state.tiers[$0] == tier.rawValue }
    }

    // Row height = item size (each row is height of the images)
    let rowHeight = itemSize
    // Row width = tierLabelWidth + nItems * itemSize + (nItems-1) * itemSpacing
    func rowWidth(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return tierLabelWidth }
        return tierLabelWidth + CGFloat(itemCount) * itemSize + CGFloat(max(0, itemCount - 1)) * itemSpacing
    }
    let maxRowWidth = displayTiers.map { rowWidth(itemCount: itemsByTier[$0]?.count ?? 0) }.max() ?? rowWidth(itemCount: 0)
    let imageWidth = maxRowWidth
    let imageHeight = CGFloat(displayTiers.count) * rowHeight

    let scale: CGFloat = 2 // 2x for sharp output
    let w = Int(imageWidth * scale)
    let h = Int(imageHeight * scale)
    guard w > 0, h > 0 else { return nil }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.scaleBy(x: scale, y: scale)

    // Load all images we need (item index -> CGImage)
    var imageCache: [Int: CGImage] = [:]
    for (_, indices) in itemsByTier {
        for idx in indices where imageCache[idx] == nil && idx < template.items.count {
            if let img = loadImage(from: template.items[idx].imageURL) {
                imageCache[idx] = img
            }
        }
    }

    // S at top, then A, B, C, D at bottom (trash tier T is not shown). CGContext has y-up, so draw from top: y = imageHeight - (rowIndex+1)*rowHeight
    for (rowIndex, tier) in displayTiers.enumerated() {
        let y = imageHeight - CGFloat(rowIndex + 1) * rowHeight
        let tierLabelRect = CGRect(x: 0, y: y, width: tierLabelWidth, height: rowHeight)
        let itemAreaRect = CGRect(x: tierLabelWidth, y: y, width: max(0, imageWidth - tierLabelWidth), height: rowHeight)

        // Tier letter background (tier color)
        if let c = tierColors[tier] {
            ctx.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
            ctx.fill(tierLabelRect)
        }

        // Tier letter (centered, black)
        drawTierLetter(tier.displayName, in: tierLabelRect, context: ctx)

        // Item area: black
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        ctx.fill(itemAreaRect)

        // Items in this tier, in URL order (index order); no spacing between items
        let indices = itemsByTier[tier] ?? []
        var x = tierLabelWidth
        for idx in indices {
            guard let cgImage = imageCache[idx] else {
                x += itemSize + itemSpacing
                continue
            }
            let itemRect = CGRect(x: x, y: y, width: itemSize, height: itemSize)
            ctx.draw(cgImage, in: itemRect)
            x += itemSize + itemSpacing
        }
    }

    return ctx.makeImage()
}

private func drawTierLetter(_ letter: String, in rect: CGRect, context ctx: CGContext) {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, tierLabelFontSize, nil)
    let color = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    let attrs = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
    guard let attrString = CFAttributedStringCreate(kCFAllocatorDefault, letter as CFString, attrs) else { return }
    let line = CTLineCreateWithAttributedString(attrString)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    // Center the line's bounding box in rect. Bounds origin can be negative (baseline/descenders).
    let drawX = rect.midX - bounds.origin.x - bounds.width / 2
    let drawY = rect.midY - bounds.origin.y - bounds.height / 2
    ctx.saveGState()
    ctx.translateBy(x: drawX, y: drawY)
    // CTLineDraw advances the context's text position; reset to (0,0) so this letter draws at the translated origin.
    // Otherwise A/B/C/D would be drawn at the end of the previous letter and drift off the label.
    ctx.textPosition = CGPoint(x: 0, y: 0)
    ctx.setFillColor(color)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

private func loadImage(from url: URL) -> CGImage? {
    var result: CGImage?
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { sem.signal() }
        guard let data = data else { return }
        #if canImport(AppKit)
        if let nsImage = NSImage(data: data),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            result = cgImage
        }
        #endif
    }.resume()
    sem.wait()
    return result
}

// MARK: - Write PNG

func writePNG(_ cgImage: CGImage, to url: URL) throws {
    let dest = url as CFURL
    guard let destination = CGImageDestinationCreateWithURL(dest, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "TierListImageScript", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create image destination"])
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "TierListImageScript", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not write PNG"])
    }
}
