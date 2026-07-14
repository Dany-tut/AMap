import SwiftUI
import MapLibre
import AMapsDomain

/// SwiftUI wrapper around MapLibre Native. Renders the CARTO Voyager raster
/// basemap plus the fog-of-war cloud layer (an exterior polygon covering the
/// city with interior holes punched out for every open cell).
struct MapLibreView: UIViewRepresentable {
    let center: Coordinate
    let fogHoles: [[Coordinate]]
    var controller: MapController?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: Self.styleURL)
        map.setCenter(
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            zoomLevel: 14, animated: false)
        map.logoView.isHidden = true
        map.compassView.isHidden = true
        map.attributionButton.isHidden = true   // demo; move to a proper spot for prod
        map.delegate = context.coordinator
        context.coordinator.map = map
        controller?.map = map
        return map
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        context.coordinator.apply(holes: fogHoles)
    }

    /// A minimal raster style written to a temp file (MapLibre needs a style URL).
    static let styleURL: URL = {
        let style = """
        {
          "version": 8,
          "sources": {
            "carto": {
              "type": "raster",
              "tiles": [
                "https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png",
                "https://b.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png",
                "https://c.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png"
              ],
              "tileSize": 256,
              "attribution": "© OpenStreetMap contributors © CARTO"
            }
          },
          "layers": [
            { "id": "bg", "type": "background", "paint": { "background-color": "#e8eef0" } },
            { "id": "carto", "type": "raster", "source": "carto" }
          ]
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("amaps-style.json")
        try? style.data(using: .utf8)?.write(to: url)
        return url
    }()

    final class Coordinator: NSObject, MLNMapViewDelegate {
        weak var map: MLNMapView?
        private var style: MLNStyle?
        private var pendingHoles: [[Coordinate]] = []
        private var lastViewportKey = ""

        private let sourceID = "fog"
        private let layerID = "fog-fill"
        private let edgeID = "fog-edge"

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            self.style = style
            style.setImage(CloudTexture.make(), forName: "clouds")
            rebuild()
        }

        /// Clouds cover the whole world, so rebuild the exterior ring to follow
        /// the camera on every move (a single world-spanning polygon isn't
        /// tessellated reliably — a padded-viewport ring always is).
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            rebuildIfMoved()
        }

        /// The initial didFinishLoading fires while the frame is still zero (so
        /// the viewport reads as the whole world); these fire once it has a real
        /// size, letting the first valid fog build land.
        func mapViewDidBecomeIdle(_ mapView: MLNMapView) {
            rebuildIfMoved()
        }

        func mapView(_ mapView: MLNMapView, didFinishRenderingMap fullyRendered: Bool) {
            rebuildIfMoved()
        }

        func apply(holes: [[Coordinate]]) {
            pendingHoles = holes
            rebuild()
        }

        /// Skip work (and avoid an idle→rebuild→idle loop) when the viewport
        /// hasn't actually moved.
        private func rebuildIfMoved() {
            guard let map else { return }
            let key = Self.viewportKey(map)
            guard key != lastViewportKey else { return }
            rebuild()
        }

        private func rebuild() {
            guard let style, let map else { return }

            // Refuse to build from an un-laid-out map (viewport reads as the whole
            // world → a world-spanning polygon that won't tessellate).
            let b = map.visibleCoordinateBounds
            let latSpan = b.ne.latitude - b.sw.latitude
            let lonSpan = b.ne.longitude - b.sw.longitude
            guard latSpan > 0, latSpan < 90, lonSpan > 0, lonSpan < 90 else { return }
            lastViewportKey = Self.viewportKey(map)

            let outer = Self.viewportRing(map)
            let feature = Self.fogFeature(outer: outer, holes: pendingHoles)

            if let existing = style.source(withIdentifier: sourceID) as? MLNShapeSource {
                existing.shape = feature
                return
            }

            let source = MLNShapeSource(identifier: sourceID, shape: feature, options: nil)
            style.addSource(source)

            // Cloud body: procedural texture, slightly translucent so the map
            // faintly glows through (the dreamy web look).
            let fill = MLNFillStyleLayer(identifier: layerID, source: source)
            if style.image(forName: "clouds") != nil {
                fill.fillPattern = NSExpression(forConstantValue: "clouds")
            } else {
                fill.fillColor = NSExpression(forConstantValue: UIColor.white)
            }
            fill.fillOpacity = NSExpression(forConstantValue: 0.9)
            style.addLayer(fill)

            // Soft feathered edge: a blurred white line along every hole/outline
            // so the corridor melts into the clouds instead of a hard cut.
            let edge = MLNLineStyleLayer(identifier: edgeID, source: source)
            edge.lineColor = NSExpression(forConstantValue: UIColor.white)
            edge.lineWidth = NSExpression(forConstantValue: 7)
            edge.lineBlur = NSExpression(forConstantValue: 9)
            edge.lineOpacity = NSExpression(forConstantValue: 0.85)
            style.addLayer(edge)
        }

        /// Coarse fingerprint of the viewport, to detect real movement.
        private static func viewportKey(_ map: MLNMapView) -> String {
            let b = map.visibleCoordinateBounds
            func r(_ v: Double) -> Int { Int((v * 2000).rounded()) }
            return "\(r(b.sw.latitude)),\(r(b.sw.longitude)),\(r(b.ne.latitude)),\(r(b.ne.longitude))"
        }

        /// A box around the viewport centre, sized to 1.7× the visible span —
        /// same construction as the (known-good) fixed demo box, just following
        /// the camera. Clamped so extreme zoom-out stays valid.
        private static func viewportRing(_ map: MLNMapView) -> [Coordinate] {
            let c = map.centerCoordinate
            let b = map.visibleCoordinateBounds
            let halfLat = min(80, abs(b.ne.latitude - b.sw.latitude) / 2 * 1.7)
            let halfLon = min(170, abs(b.ne.longitude - b.sw.longitude) / 2 * 1.7)
            let minLat = c.latitude - halfLat, maxLat = c.latitude + halfLat
            let minLon = c.longitude - halfLon, maxLon = c.longitude + halfLon
            return [
                Coordinate(latitude: minLat, longitude: minLon),
                Coordinate(latitude: minLat, longitude: maxLon),
                Coordinate(latitude: maxLat, longitude: maxLon),
                Coordinate(latitude: maxLat, longitude: minLon),
            ]
        }

        /// Builds one polygon feature: exterior cloud ring with each open cell
        /// as an interior hole.
        private static func fogFeature(outer: [Coordinate], holes: [[Coordinate]]) -> MLNPolygonFeature {
            let holePolys: [MLNPolygon] = holes.map { ring in
                var coords = ring.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                return MLNPolygon(coordinates: &coords, count: UInt(coords.count))
            }
            var outerCoords = outer.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            return MLNPolygonFeature(
                coordinates: &outerCoords, count: UInt(outerCoords.count),
                interiorPolygons: holePolys)
        }
    }
}
