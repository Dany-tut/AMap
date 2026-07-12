import Foundation
import AMapsDomain
import AMapsFog

// Generates a real fog-of-war GeoJSON by driving a sample outing through the
// actual FogEngine + SlippyGrid, then serialising with FogGeoJSON. The web
// prototype (web/index.html) loads the output, so what you see on the map is
// produced by the same core the iOS app will use.

/// A bike ride through Da Nang: Han riverfront (Bạch Đằng) → Dragon Bridge →
/// Võ Văn Kiệt → My Khe beach (Võ Nguyên Giáp) north.
///
/// The path is loaded from `web/route.json` (an `[[lon, lat], …]` polyline snapped
/// to real roads by OSRM); a coarse fallback keeps the tool runnable offline.
func loadWaypoints() -> [Coordinate] {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("web/route.json")
    if let data = try? Data(contentsOf: url),
       let pts = try? JSONSerialization.jsonObject(with: data) as? [[Double]], !pts.isEmpty {
        return pts.map { Coordinate(latitude: $0[1], longitude: $0[0]) }
    }
    return [
        Coordinate(latitude: 16.0710, longitude: 108.2235),
        Coordinate(latitude: 16.0612, longitude: 108.2280),
        Coordinate(latitude: 16.0606, longitude: 108.2340),
        Coordinate(latitude: 16.0598, longitude: 108.2468),
        Coordinate(latitude: 16.0710, longitude: 108.2452),
    ]
}
let waypoints = loadWaypoints()

/// Densely interpolate between waypoints so consecutive z17 tiles get opened.
func route(_ pts: [Coordinate], step: Double = 0.00035) -> [Coordinate] {
    var out: [Coordinate] = []
    for i in 0..<(pts.count - 1) {
        let a = pts[i], b = pts[i + 1]
        let dLat = b.latitude - a.latitude, dLon = b.longitude - a.longitude
        let dist = (dLat * dLat + dLon * dLon).squareRoot()
        let n = max(1, Int(dist / step))
        for k in 0...n {
            let t = Double(k) / Double(n)
            out.append(Coordinate(latitude: a.latitude + dLat * t,
                                  longitude: a.longitude + dLon * t))
        }
    }
    return out
}

let grid = SlippyGrid(zoom: 17)
let engine = FogEngine(grid: grid)
let start = Date(timeIntervalSince1970: 1_752_000_000)

var opened = 0
for (i, coord) in route(waypoints).enumerated() {
    let t = start.addingTimeInterval(Double(i) * 8)  // ~8s between fixes
    if engine.observe(coord, at: t, activity: .cycling) != nil { opened += 1 }
}

let cells = engine.allVisited()
let geojson = try FogGeoJSON(grid: grid).data(for: cells)

// Map center = mean of waypoints.
let centerLat = waypoints.map(\.latitude).reduce(0, +) / Double(waypoints.count)
let centerLon = waypoints.map(\.longitude).reduce(0, +) / Double(waypoints.count)

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("web")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try geojson.write(to: outDir.appendingPathComponent("fog.geojson"))

// The actual GPS track — the web prototype buffers this into a corridor so the
// reveal hugs the street ridden, not the whole block a coarse cell would open.
let track: [String: Any] = [
    "type": "Feature", "properties": [:],
    "geometry": ["type": "LineString", "coordinates": waypoints.map { [$0.longitude, $0.latitude] }],
]
try JSONSerialization.data(withJSONObject: track).write(to: outDir.appendingPathComponent("track.geojson"))

let meta = ["center": [centerLon, centerLat], "zoom": 14.4, "cells": Double(opened)] as [String: Any]
try JSONSerialization.data(withJSONObject: meta)
    .write(to: outDir.appendingPathComponent("meta.json"))

print("Wrote web/fog.geojson — \(opened) cells opened, center \(centerLat), \(centerLon)")
