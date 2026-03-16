import Foundation
import Compression

/// Tier levels: S=1, A=2, B=3, C=4, D=5, T=6 (trash). Matches app GameState.
enum Tier: Int, Codable, CaseIterable {
    case S = 1
    case A = 2
    case B = 3
    case C = 4
    case D = 5
    case T = 6  // Trash: encoded in URL, never displayed

    /// Tiers shown in the tier list (excludes trash).
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
}

/// Decoded state from app URL: template index + tier per item index (0 = unranked).
struct DecodedState {
    let templateIndex: Int
    /// tiers[itemIndex] = Tier.rawValue, or 0 if unranked
    let tiers: [Int]
    /// Optional: template indices in display order (preserves order within tiers). When nil, use template index order.
    let order: [Int]?
}

/// Compact payload in app URL query (state=). Matches GameState.CompactState.
private struct CompactState: Codable {
    let ti: Int
    let p1: String
    let p2: String?
    let c: String
    let o: Bool
    let t: [Int]
    let ord: [Int]?  // display order: template indices (optional)
    let lp: Int?     // lastPlacedItemIndex (optional for backwards compatibility)
    let v: Bool?     // lastMoveWasVeto (optional for backwards compatibility)
}

private let urlQueryKey = "state"

func decodeState(from url: URL) -> DecodedState? {
    guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
          let encoded = queryItems.first(where: { $0.name == urlQueryKey })?.value else {
        return nil
    }
    return decodeState(fromEncodedQueryValue: encoded)
}

func decodeState(fromEncodedQueryValue encoded: String) -> DecodedState? {
    let raw = encoded.removingPercentEncoding ?? encoded
    let standard = raw
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let padding = (4 - standard.count % 4) % 4
    let padded = standard + String(repeating: "=", count: padding)
    guard let data = Data(base64Encoded: padded) else { return nil }
    for algorithm: compression_algorithm in [COMPRESSION_LZFSE, COMPRESSION_ZLIB] {
        if let decompressed = data.decompressed(algorithm: algorithm),
           let compact = try? JSONDecoder().decode(CompactState.self, from: decompressed) {
            return DecodedState(templateIndex: compact.ti, tiers: compact.t, order: compact.ord)
        }
    }
    return nil
}

// MARK: - Data decompression (matches app GameState extension)

extension Data {
    func decompressed(algorithm: compression_algorithm = COMPRESSION_LZFSE) -> Data? {
        let destCapacity = 2 * 1024 * 1024
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
        defer { dest.deallocate() }
        let written = withUnsafeBytes { src in
            compression_decode_buffer(
                dest, destCapacity,
                src.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, algorithm
            )
        }
        guard written > 0 else { return nil }
        return Data(bytes: dest, count: written)
    }
}
