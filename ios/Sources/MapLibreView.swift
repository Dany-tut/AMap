import SwiftUI
import MapLibre
import AMapsDomain

/// SwiftUI wrapper around MapLibre Native. Renders the same CARTO Voyager
/// raster basemap the web prototype uses.
struct MapLibreView: UIViewRepresentable {
    let center: Coordinate

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: Self.styleURL)
        map.setCenter(
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            zoomLevel: 14, animated: false)
        map.logoView.isHidden = true
        map.compassView.isHidden = true
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {}

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
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Fog-of-war overlay lands in the next milestone.
        }
    }
}
