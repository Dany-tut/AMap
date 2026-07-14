import UIKit

/// Procedural, seamlessly-tiling cloud texture — an opaque white sheet with
/// soft tonal lumps (highlights + shadows in the gaps) so the fog reads as
/// fluffy clouds instead of flat paint. Mirrors the web prototype's canvas
/// cloud pattern. Deterministic (seeded) so it never flickers between builds.
enum CloudTexture {
    static func make(size: CGFloat = 256, scale: CGFloat = 2) -> UIImage {
        var rng = SeededRNG(seed: 0xC10D)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: size, height: size), format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Opaque white base — unexplored ground stays hidden under cloud.
            cg.setFillColor(UIColor(white: 1.0, alpha: 1.0).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

            // Soft shadow pockets carve volume between the puffs.
            drawBlobs(cg, size: size, count: 16, rng: &rng,
                      inner: UIColor(red: 0.80, green: 0.82, blue: 0.90, alpha: 0.55),
                      rMin: 0.10, rMax: 0.22)
            // Bright highlights lift the tops.
            drawBlobs(cg, size: size, count: 20, rng: &rng,
                      inner: UIColor(white: 1.0, alpha: 0.9),
                      rMin: 0.08, rMax: 0.18)
        }
    }

    private static func drawBlobs(_ cg: CGContext, size: CGFloat, count: Int,
                                  rng: inout SeededRNG, inner: UIColor,
                                  rMin: Double, rMax: Double) {
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [inner.cgColor, inner.withAlphaComponent(0).cgColor] as CFArray
        guard let grad = CGGradient(colorsSpace: space, colors: colors,
                                    locations: [0, 1]) else { return }
        for _ in 0..<count {
            let bx = CGFloat(rng.next()) * size
            let by = CGFloat(rng.next()) * size
            let r = size * CGFloat(rMin + rng.next() * (rMax - rMin))
            // Draw at every wrap offset so the tile is seamless.
            for dx in [-size, 0, size] {
                for dy in [-size, 0, size] {
                    let c = CGPoint(x: bx + dx, y: by + dy)
                    cg.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                          endCenter: c, endRadius: r, options: [])
                }
            }
        }
    }
}

/// Tiny deterministic PRNG (SplitMix64-ish) — avoids frame-to-frame flicker.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
