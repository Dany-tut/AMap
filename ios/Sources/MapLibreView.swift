import SwiftUI
import MapLibre
import AMapsDomain

/// SwiftUI wrapper around MapLibre Native. Renders the CARTO Voyager raster
/// basemap plus the fog-of-war cloud layer (an exterior polygon covering the
/// city with interior holes punched out for every open cell).
struct MapLibreView: UIViewRepresentable {
    let center: Coordinate
    let fogOuter: [Coordinate]
    let fogHoles: [[Coordinate]]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: Self.styleURL)
        map.setCenter(
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            zoomLevel: 14, animated: false)
        map.logoView.isHidden = true
        map.compassView.isHidden = true
        map.delegate = context.coordinator
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        context.coordinator.apply(outer: fogOuter, holes: fogHoles)
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
        private var pendingOuter: [Coordinate] = []
        private var pendingHoles: [[Coordinate]] = []

        private let sourceID = "fog"
        private let layerID = "fog-fill"
        private let edgeID = "fog-edge"

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            self.style = style
            style.setImage(CloudTexture.make(), forName: "clouds")
            rebuild()
        }

        func apply(outer: [Coordinate], holes: [[Coordinate]]) {
            pendingOuter = outer
            pendingHoles = holes
            rebuild()
        }

        private func rebuild() {
            guard let style, !pendingOuter.isEmpty else { return }

            let feature = Self.fogFeature(outer: pendingOuter, holes: pendingHoles)

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
