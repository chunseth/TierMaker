import Foundation

// Usage:
//   TierListImageScript <url> [output.png]   — decode state from URL, render, write PNG
//   TierListImageScript --random <templateIndex> [output.png]   — assign random tiers to template, render (for layout tweaking)
// Template index: 0 = Ranked Anime, 1 = Movies, 2 = Video Games, 3 = Fast Food, 4 = Streaming Services, 5 = Cereals

func main() {
    let args = CommandLine.arguments.dropFirst()
    guard !args.isEmpty else {
        print("Usage: TierListImageScript <url> [output.png]")
        print("   or: TierListImageScript --random <templateIndex> [output.png]")
        print("Template indices: 0=Ranked Anime, 1=Movies, 2=Video Games, 3=Fast Food, 4=Streaming Services, 5=Cereals")
        exit(1)
    }

    let state: DecodedState
    let outputPath: String

    if args.first == "--random" {
        guard args.count >= 2, let templateIndex = Int(args.dropFirst().first!), templateIndex >= 0, templateIndex < Template.all.count else {
            print("Error: --random requires a valid template index (0..<\(Template.all.count))")
            exit(1)
        }
        let template = Template.all[templateIndex]
        state = DecodedState(
            templateIndex: templateIndex,
            tiers: (0..<template.items.count).map { _ in Tier.displayTiers.randomElement()!.rawValue }
        )
        outputPath = args.count >= 3 ? String(args.dropFirst(2).first!) : "tierlist_random_\(templateIndex).png"
        print("Random tiers assigned for template '\(template.name)'. Output: \(outputPath)")
    } else {
        guard let urlString = args.first, let url = URL(string: urlString) else {
            print("Error: invalid URL")
            exit(1)
        }
        guard let decoded = decodeState(from: url) else {
            print("Error: could not decode state from URL")
            exit(1)
        }
        state = decoded
        outputPath = args.count >= 2 ? String(args[1]) : "tierlist.png"
    }

    let template = Template.all[state.templateIndex]
    guard let cgImage = renderTierListImage(state: state, template: template) else {
        print("Error: failed to render image")
        exit(1)
    }

    let outURL = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath)
    do {
        try writePNG(cgImage, to: outURL)
        print("Wrote \(outURL.path)")
    } catch {
        print("Error writing PNG: \(error)")
        exit(1)
    }
}

main()
