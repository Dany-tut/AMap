import Foundation
import AMapsDomain

/// A simple deterministic grid based on web-mercator slippy-map tiles at a
/// fixed zoom. Used as the default projection and in tests. Production can
/// swap in an H3-backed `GridProjection` without touching `FogEngine`.
public struct SlippyGrid: GridProjection {
    public let zoom: Int
    public init(zoom: Int = 17) { self.zoom = zoom }

    public func cell(for coordinate: Coordinate) -> CellIndex {
        let n = Double(1 << zoom)
        let x = UInt64((coordinate.longitude + 180.0) / 360.0 * n)
        let latRad = coordinate.latitude * .pi / 180.0
        let y = UInt64((1.0 - asinh(tan(latRad)) / .pi) / 2.0 * n)
        // Pack (z, x, y) into one 64-bit index: 5 bits zoom, then x, then y.
        let packed = (UInt64(zoom) << 58) | (x << 29) | (y & 0x1FFFFFFF)
        return CellIndex(rawValue: packed)
    }
}
