import SwiftUI
import AMapsDomain

extension ActivityType {
    var emoji: String {
        switch self {
        case .walking: "🚶"
        case .cycling: "🚲"
        case .automotive: "🚗"
        case .unknown: "🧭"
        }
    }
    var label: String {
        switch self {
        case .walking: "Пешком"
        case .cycling: "Вело"
        case .automotive: "Авто"
        case .unknown: "—"
        }
    }
}

private let accent = Color(red: 0.486, green: 0.424, blue: 0.941) // #7c6cf0
private let ink = Color(red: 0.227, green: 0.208, blue: 0.314)     // #3a3550

/// One morphing dock icon: interpolates from a collapsed x-fraction (flanking
/// the centred «Поехали») to an expanded one (evenly spread, with a label).
struct DockItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let x0: CGFloat
    let x1: CGFloat
    var fadeIn: Bool = false      // Туман only exists in the open state
    let action: () -> Void
}

enum DockSheet: String, Identifiable {
    case search = "Поиск", journal = "Дневник", trophies = "Трофеи", profile = "Профиль"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .search: "magnifyingglass"
        case .journal: "book"
        case .trophies: "trophy"
        case .profile: "safari"
        }
    }
}

struct MapScreen: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var map = MapController()
    @State private var sheet: DockSheet?
    @State private var showRegions = false
    @State private var dockProgress: CGFloat = 0   // 0 collapsed … 1 expanded
    @State private var dragStart: CGFloat = 0

    /// Equal inset for the floating dock — left, right and bottom all use this.
    /// Dock inset shrinks as it expands: a slimmer bar collapsed, nearly
    /// edge-to-edge when open. Corner radius grows toward the iPhone's own
    /// screen curvature so the open dock reads as concentric with the device.
    private var dockMargin: CGFloat { lerp(26, 11, dockProgress) }
    private var dockCorner: CGFloat { lerp(30, 52, dockProgress) }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapLibreView(center: model.center,
                         fogHoles: model.fogHoles,
                         controller: map)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    regionPill
                    activityPill
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()
                    rightStack
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 96)   // keep the right stack above the dock

            // Floating dock — equal margins from the screen edges.
            dock
                .padding(.horizontal, dockMargin)
                .padding(.bottom, dockMargin)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(item: $sheet) { s in
            Group {
                switch s {
                case .search: SearchSheet(map: map)
                case .trophies: TrophySheet(trophies: model.trophies)
                default: DockSheetView(sheet: s)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRegions) {
            RegionSheet(model: model, map: map)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Top pills

    private var regionPill: some View {
        Button { showRegions = true } label: {
            HStack(spacing: 5) {
                Text("🗺️")
                Text(model.regionName).fontWeight(.semibold).foregroundStyle(ink)
                Text("·").foregroundStyle(.secondary)
                Text("\(model.coveragePercent)%").fontWeight(.bold).foregroundStyle(accent)
                Text("открыто").foregroundStyle(ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .fixedSize()
            .pillStyle()
        }
    }

    /// Auto-detected activity (CoreMotion). Tap to override / demo.
    private var activityPill: some View {
        Button { model.cycleActivity() } label: {
            HStack(spacing: 5) {
                Text(model.activity.emoji)
                Text(model.activity.label).foregroundStyle(ink)
            }
            .lineLimit(1)
            .fixedSize()
            .pillStyle()
        }
    }

    // MARK: Right control stack (locate + zoom)

    private var rightStack: some View {
        VStack(spacing: 10) {
            roundButton(system: "location.fill", tint: accent) {
                map.recenter(on: model.center)
            }
            roundButton(system: "plus", tint: ink) { map.zoomIn() }
            roundButton(system: "minus", tint: ink) { map.zoomOut() }
        }
    }

    // MARK: Bottom dock (nav bar) — continuous morph, like the web

    // Morph geometry (points).
    private let topPad: CGFloat = 12
    private let botPad: CGFloat = 10
    private let statsH: CGFloat = 84      // stats band height when open
    private let iconH: CGFloat = 46       // icon glyph row height
    private let labelH: CGFloat = 18      // label height when open
    private let goH0: CGFloat = 50        // collapsed pill height
    private let goH1: CGFloat = 58        // expanded bar height
    private let goW0: CGFloat = 138       // collapsed pill width
    private let dragRange: CGFloat = 150  // drag distance for a full morph

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    /// Five icons: collapsed x-fraction (flanking the centred Поехали) → expanded
    /// x-fraction (evenly spread). Туман only appears when open.
    private var dockItems: [DockItem] {
        [
            .init(icon: "magnifyingglass", label: "Поиск",  x0: 0.09, x1: 0.10, action: { sheet = .search }),
            .init(icon: "book",           label: "Дневник", x0: 0.24, x1: 0.30, action: { sheet = .journal }),
            .init(icon: "trophy",         label: "Трофеи",  x0: 0.76, x1: 0.50, action: { sheet = .trophies }),
            .init(icon: "safari",         label: "Компас",  x0: 0.91, x1: 0.70, action: { sheet = .profile }),
            .init(icon: "cloud",          label: "Туман",   x0: 0.90, x1: 0.90, fadeIn: true, action: { map.toggleFog() }),
        ]
    }

    private func dockHeight(_ p: CGFloat) -> CGFloat {
        topPad + statsH * p + (iconH + labelH * p) + (goH1 + 12) * p + botPad
    }

    /// Grabber sits in its own zone above the glass (within the dock's bounds so
    /// it stays hit-testable) — the whole dock is one VStack.
    private var dock: some View {
        VStack(spacing: 0) {
            grabber
            dockBody
        }
    }

    private var dockBody: some View {
        let p = dockProgress
        return GeometryReader { geo in
            let W = geo.size.width
            ZStack {
                // Stats band (fades/scales in at the top).
                dockStats
                    .frame(width: W - 24)
                    .opacity(p)
                    .position(x: W / 2, y: topPad + statsH * p / 2)

                // Icons — positions interpolate; labels fade in.
                ForEach(dockItems) { item in
                    dockIconView(item, p: p)
                        .position(x: lerp(item.x0, item.x1, p) * W,
                                  y: topPad + statsH * p + (iconH + labelH * p) / 2)
                }

                // «Поехали» morphs from a centred pill to a full-width bottom bar.
                goButton(width: lerp(goW0, W - 24, p), height: lerp(goH0, goH1, p))
                    .position(x: W / 2,
                              y: lerp(topPad + iconH / 2, dockHeight(p) - botPad - goH1 / 2, p))
            }
            .frame(width: W, height: dockHeight(p))
        }
        .frame(height: dockHeight(p))
        .background(
            ZStack {
                // Translucent floating glass when collapsed; densifies into a
                // sheet-like frosted panel as it opens (matches the system sheet).
                RoundedRectangle(cornerRadius: dockCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: dockCorner, style: .continuous)
                    .fill(Color.white.opacity(0.55 * dockProgress))
            }
            .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: dockCorner, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: dockCorner, style: .continuous))
    }

    /// Pull-tab above the glass — the only drag target (a second gesture on the
    /// dock body fought this one and made the morph judder).
    private var grabber: some View {
        Capsule()
            .fill(Color(white: 0.68))
            .frame(width: 42, height: 6)
            .frame(maxWidth: .infinity)
            .padding(.top, 7)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .gesture(dockDrag)
            .onTapGesture { snapDock(dockProgress > 0.5 ? 0 : 1) }
    }

    /// Global coordinate space — the grabber moves up as the dock grows, so a
    /// local translation would feed back on itself and make the morph judder.
    private var dockDrag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                dockProgress = min(1, max(0, dragStart - v.translation.height / dragRange))
            }
            .onEnded { v in
                let open = v.predictedEndTranslation.height < -40 || dockProgress > 0.5
                snapDock(open ? 1 : 0)
            }
    }

    private func snapDock(_ target: CGFloat) {
        dragStart = target
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) { dockProgress = target }
    }

    private var dockStats: some View {
        HStack(spacing: 8) {
            stat("\(model.coveragePercent)%", "открыто")
            stat("\(model.cellCount)", "ячеек")
            stat("\(model.unlockedTrophyCount)", "трофеев")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).foregroundStyle(accent)
            Text(label).font(.caption).foregroundStyle(ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.5)))
    }

    private func dockIconView(_ item: DockItem, p: CGFloat) -> some View {
        Button(action: item.action) {
            VStack(spacing: 3) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 24)          // uniform glyph box → labels align
                    .foregroundStyle(ink)
                Text(item.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.75))
                    .fixedSize()
                    .frame(height: labelH * p)
                    .opacity(p)
            }
            .frame(width: 60)
            .contentShape(Rectangle())
        }
        .opacity(item.fadeIn ? p : 1)
        .allowsHitTesting(item.fadeIn ? p > 0.5 : true)
    }

    private func goButton(width: CGFloat, height: CGFloat) -> some View {
        Button(action: model.toggleRide) {
            Label(model.riding ? "Стоп" : "Поехали",
                  systemImage: model.riding ? "stop.fill" : "play.fill")
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white)
                .frame(width: width, height: height)
                .background(Capsule().fill(model.riding ? Color.red.opacity(0.85) : accent))
                .shadow(color: accent.opacity(0.4), radius: 12, y: 5)
        }
    }

    // MARK: Reusable round glass button

    private func roundButton(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
    }
}

/// City switcher — pick a region, fly there, update the pill.
struct RegionSheet: View {
    @ObservedObject var model: AppModel
    let map: MapController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Города")
                .font(.headline).foregroundStyle(ink)
                .padding(.top, 22).padding(.bottom, 8)

            List(AppModel.regions) { r in
                Button {
                    model.selectRegion(r)
                    map.recenter(on: r.center)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text(r.emoji).font(.title3)
                        Text(r.name).foregroundStyle(.primary)
                        Spacer()
                        Text(r.coverage > 0 ? "\(r.coverage)%" : "—")
                            .fontWeight(.semibold)
                            .foregroundStyle(r.name == model.regionName ? accent : .secondary)
                        if r.name == model.regionName {
                            Image(systemName: "checkmark").foregroundStyle(accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
}

/// Placeholder content for each dock destination until the real screens land.
struct DockSheetView: View {
    let sheet: DockSheet

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: sheet.icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.top, 40)
            Text(sheet.rawValue)
                .font(.title2.bold())
                .foregroundStyle(ink)
            Text("Скоро")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    func pillStyle() -> some View {
        self
            .font(.system(size: 13.5, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.9)))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
