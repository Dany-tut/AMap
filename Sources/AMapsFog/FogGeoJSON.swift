import Foundation
import AMapsDomain

/// Serialises revealed cells into a GeoJSON `FeatureCollection` of polygons.
///
/// MapLibre renders the fog as a dark full-screen fill; this revealed layer is
/// drawn on top with a "clear"/destination-out blend (or simply as the bright
/// explored area), so the world shows through exactly where the player has been.
/// The engine emits only the cells near the current viewport to keep the source
/// light even when hundreds of thousands of cells are open globally.
public struct FogGeoJSON {
    private let grid: GridProjection
    public init(grid: GridProjection) { self.grid = grid }

    /// Build a FeatureCollection for `cells`. Pass a viewport bbox to emit only
    /// the cells that intersect it (recommended for the live map).
    public func featureCollection(for cells: [VisitedCell],
                                  within bbox: BoundingBox? = nil) -> [String: Any] {
        var features: [[String: Any]] = []
        features.reserveCapacity(cells.count)
        for cell in cells {
            let ring = grid.polygon(for: cell.index)
            if let bbox, !bbox.intersects(ring) { continue }
            var coords = ring.map { [$0.longitude, $0.latitude] }
            if let first = coords.first { coords.append(first) } // close the ring
            features.append([
                "type": "Feature",
                "properties": ["activity": cell.activity.rawValue],
                "geometry": ["type": "Polygon", "coordinates": [coords]],
            ])
        }
        return ["type": "FeatureCollection", "features": features]
    }

    /// Convenience: serialised UTF-8 JSON ready to hand to a MapLibre source.
    public func data(for cells: [VisitedCell], within bbox: BoundingBox? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: featureCollection(for: cells, within: bbox))
    }
}

public struct BoundingBox: Sendable {
    public let minLat, minLon, maxLat, maxLon: Double
    public init(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        self.minLat = minLat; self.minLon = minLon
        self.maxLat = maxLat; self.maxLon = maxLon
    }
    /// True if any vertex of `ring` falls inside the box (cheap, good enough for
    /// tile-sized cells where the box is far larger than a cell).
    public func intersects(_ ring: [Coordinate]) -> Bool {
        ring.contains { c in
            c.latitude >= minLat && c.latitude <= maxLat &&
            c.longitude >= minLon && c.longitude <= maxLon
        }
    }
}
