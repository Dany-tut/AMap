import MapLibre
import AMapsDomain

/// Thin bridge so SwiftUI controls (zoom / locate) can drive the MapLibre view.
@MainActor
final class MapController: ObservableObject {
    weak var map: MLNMapView?

    func zoomIn() {
        guard let map else { return }
        map.setZoomLevel(map.zoomLevel + 1, animated: true)
    }

    func zoomOut() {
        guard let map else { return }
        map.setZoomLevel(map.zoomLevel - 1, animated: true)
    }

    func recenter(on coord: Coordinate, zoom: Double = 14) {
        map?.setCenter(
            CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
            zoomLevel: zoom, animated: true)
    }
}
