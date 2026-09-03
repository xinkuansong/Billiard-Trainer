import SwiftUI
import SceneKit

// MARK: - Metrics (G21 / D7)

/// Shared ball-palette metrics. Diameters are the only two tiers (D7):
/// regular 36 is the App-wide interactive / decorative / reference default
/// (Composer / ShotSim / Silu / PlanThree / Snooker / Bank / Diamond / Extraction /
/// Batch shells / FreePlay reference / decorative quiz chrome).
/// compact 30 remains as a numeric tier constant (no current consumers after K5/X2).
enum BTBallPaletteMetrics {
    /// Legacy D7 compact tier (30). Kept for API stability; no call sites after K5/X2.
    static let compactDiameter: CGFloat = 30
    static let regularDiameter: CGFloat = 36
    static let ghostDiameter: CGFloat = 42
    static let columns = 8
    static let rowSpacing: CGFloat = 3
    static let minimumHitSize: CGFloat = 44
    static let dragMinimumDistance: CGFloat = 10
    static let faceStroke = Color.white.opacity(0.18)
    static let faceStrokeWidth: CGFloat = 0.5
    static let dimmedOpacity: Double = 0.3
    static let ghostSuccessLineWidth: CGFloat = 2.5
    static let ghostIdleLineWidth: CGFloat = 1
    static let ghostIdleStroke = Color.white.opacity(0.4)

    static func slotHeight(for diameter: CGFloat) -> CGFloat {
        max(minimumHitSize, diameter + 2)
    }
}

// MARK: - Drag ghost (shared overlay)

/// Floating ghost that follows the finger during a palette drag.
struct BTBallPaletteDragGhost: View {
    let key: String
    let location: CGPoint
    let overTable: Bool

    var body: some View {
        PoolBallFace(key: key, diameter: BTBallPaletteMetrics.ghostDiameter)
            .overlay(
                Circle().stroke(
                    overTable ? Color.btSuccess : BTBallPaletteMetrics.ghostIdleStroke,
                    lineWidth: overTable
                        ? BTBallPaletteMetrics.ghostSuccessLineWidth
                        : BTBallPaletteMetrics.ghostIdleLineWidth
                )
            )
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .position(location)
            .allowsHitTesting(false)
    }
}

// MARK: - Interactive token (Extraction / custom chrome)

/// Single palette slot with tap + drag-to-place. Used by pages whose bottom
/// chrome is not a full-width G8 bar (e.g. Extraction confirm strip).
struct BTBallPaletteToken: View {
    let key: String
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var isOnTable: Bool
    var isDragging: Bool
    var allowsDrag: Bool = true
    var isPlaying: Bool = false
    let coordinateSpace: String
    var sceneFrame: CGRect
    var unproject: ((CGPoint) -> SCNVector3?)? = nil
    var onTap: () -> Void
    var onPlace: (SCNVector3?) -> Void
    var onDragInteraction: (() -> Void)? = nil
    @Binding var draggingKey: String?
    @Binding var dragLocation: CGPoint
    @Binding var dragOverTable: Bool

    private var slot: CGFloat { BTBallPaletteMetrics.slotHeight(for: ballDiameter) }

    var body: some View {
        PoolBallFace(key: key, diameter: ballDiameter)
            .overlay(Circle().stroke(BTBallPaletteMetrics.faceStroke,
                                     lineWidth: BTBallPaletteMetrics.faceStrokeWidth))
            .frame(width: slot, height: slot)
            .contentShape(Rectangle())
            .opacity(isDragging ? BTBallPaletteMetrics.dimmedOpacity
                     : (isOnTable ? BTBallPaletteMetrics.dimmedOpacity : 1))
            .accessibilityElement()
            .accessibilityIdentifier("paletteBall_\(key)")
            .onTapGesture(perform: onTap)
            .gesture(paletteDrag, including: allowsDrag ? .all : .subviews)
    }

    private var paletteDrag: some Gesture {
        DragGesture(minimumDistance: BTBallPaletteMetrics.dragMinimumDistance,
                    coordinateSpace: .named(coordinateSpace))
            .onChanged { value in
                guard !isPlaying else { return }
                onDragInteraction?()
                draggingKey = key
                dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }
            .onEnded { value in
                let loc = value.location
                defer { draggingKey = nil; dragOverTable = false }
                guard !isPlaying, sceneFrame.contains(loc) else { return }
                let local = CGPoint(x: loc.x - sceneFrame.minX, y: loc.y - sceneFrame.minY)
                onPlace(unproject?(local))
            }
    }
}

// MARK: - Interactive / reference palette bar (G21)

/// Two-row × 8-column ball library. Pages pass only deltas
/// (`coordinateSpace`, `ballDiameter`, `isPlaying`, callbacks).
struct BTBallPaletteBar: View {
    let coordinateSpace: String
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var isPlaying: Bool = false
    var libraryWidth: CGFloat
    var keys: [String] = PositionPlayBall.allKeys

    /// Whether the key is already on the table (drives dim opacity).
    var isOnTable: (String) -> Bool
    /// When false, only subview gestures fire (on-table / fixed balls).
    /// Defaults to `!isOnTable(key)`.
    var allowsDrag: ((String) -> Bool)? = nil

    var sceneFrame: CGRect = .zero
    var unproject: ((CGPoint) -> SCNVector3?)? = nil

    var onTap: (String) -> Void
    var onPlace: (String, SCNVector3?) -> Void
    var onDragInteraction: (() -> Void)? = nil

    @Binding var draggingKey: String?
    @Binding var dragLocation: CGPoint
    @Binding var dragOverTable: Bool

    private var columnWidth: CGFloat {
        max(libraryWidth / CGFloat(BTBallPaletteMetrics.columns), 1)
    }

    private var slotHeight: CGFloat {
        BTBallPaletteMetrics.slotHeight(for: ballDiameter)
    }

    var body: some View {
        let row1 = Array(keys.prefix(BTBallPaletteMetrics.columns))
        let row2 = Array(keys.dropFirst(BTBallPaletteMetrics.columns))
        return VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
            paletteRow(row1)
            paletteRow(row2)
        }
        .frame(width: libraryWidth)
    }

    private func paletteRow(_ rowKeys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<BTBallPaletteMetrics.columns, id: \.self) { i in
                Group {
                    if i < rowKeys.count {
                        token(rowKeys[i])
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth, height: slotHeight)
            }
        }
    }

    private func token(_ key: String) -> some View {
        let onTable = isOnTable(key)
        let canDrag = allowsDrag?(key) ?? !onTable
        return BTBallPaletteToken(
            key: key,
            ballDiameter: ballDiameter,
            isOnTable: onTable,
            isDragging: draggingKey == key,
            allowsDrag: canDrag,
            isPlaying: isPlaying,
            coordinateSpace: coordinateSpace,
            sceneFrame: sceneFrame,
            unproject: unproject,
            onTap: { onTap(key) },
            onPlace: { world in onPlace(key, world) },
            onDragInteraction: onDragInteraction,
            draggingKey: $draggingKey,
            dragLocation: $dragLocation,
            dragOverTable: $dragOverTable
        )
    }
}

// MARK: - Decorative (read-only) palette (C14)

/// Sister of `BTBallPaletteBar` for quiz chrome: same two-row layout and face
/// styling, no tap/drag. Chosen over a mode flag so interactive pages never
/// need dummy drag bindings.
struct BTDecorativeBallPalette: View {
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var libraryWidth: CGFloat
    var keys: [String] = PositionPlayBall.allKeys
    /// Opacity per key (e.g. target ball = 1, others = 0.25).
    var opacityForKey: (String) -> Double

    private var columnWidth: CGFloat {
        max(libraryWidth / CGFloat(BTBallPaletteMetrics.columns), 1)
    }

    private var slotHeight: CGFloat {
        BTBallPaletteMetrics.slotHeight(for: ballDiameter)
    }

    var body: some View {
        let row1 = Array(keys.prefix(BTBallPaletteMetrics.columns))
        let row2 = Array(keys.dropFirst(BTBallPaletteMetrics.columns))
        return VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
            decorativeRow(row1)
            decorativeRow(row2)
        }
        .frame(width: libraryWidth)
        .allowsHitTesting(false)
    }

    private func decorativeRow(_ rowKeys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(rowKeys, id: \.self) { key in
                PoolBallFace(key: key, diameter: ballDiameter)
                    .overlay(Circle().stroke(BTBallPaletteMetrics.faceStroke,
                                             lineWidth: BTBallPaletteMetrics.faceStrokeWidth))
                    .frame(width: columnWidth, height: slotHeight)
                    .opacity(opacityForKey(key))
            }
        }
    }
}

// MARK: - Reference palette (FreePlay: tap only, no drag)

/// FreePlay-style remaining-ball reference: dim on-table balls, tap to pulse
/// or show a page message — no drag-to-place.
struct BTReferenceBallPalette: View {
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var libraryWidth: CGFloat
    var keys: [String] = PositionPlayBall.allKeys
    var isOnTable: (String) -> Bool
    /// On-table opacity (FreePlay uses 0.28); off-table uses `availableOpacity`.
    var onTableOpacity: Double = 0.28
    var availableOpacity: Double = 0.85
    var onTap: (String, Bool /* onTable */) -> Void

    private var columnWidth: CGFloat {
        max(libraryWidth / CGFloat(BTBallPaletteMetrics.columns), 1)
    }

    private var slotHeight: CGFloat {
        BTBallPaletteMetrics.slotHeight(for: ballDiameter)
    }

    var body: some View {
        let row1 = Array(keys.prefix(BTBallPaletteMetrics.columns))
        let row2 = Array(keys.dropFirst(BTBallPaletteMetrics.columns))
        return VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
            referenceRow(row1)
            referenceRow(row2)
        }
        .frame(width: libraryWidth)
    }

    private func referenceRow(_ rowKeys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<BTBallPaletteMetrics.columns, id: \.self) { i in
                Group {
                    if i < rowKeys.count {
                        let key = rowKeys[i]
                        let onTable = isOnTable(key)
                        PoolBallFace(key: key, diameter: ballDiameter)
                            .overlay(Circle().stroke(BTBallPaletteMetrics.faceStroke,
                                                     lineWidth: BTBallPaletteMetrics.faceStrokeWidth))
                            .frame(width: slotHeight, height: slotHeight)
                            .contentShape(Rectangle())
                            .opacity(onTable ? onTableOpacity : availableOpacity)
                            .accessibilityElement()
                            .accessibilityLabel(key)
                            .accessibilityIdentifier("paletteBall_\(key)")
                            .onTapGesture { onTap(key, onTable) }
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth, height: slotHeight)
            }
        }
    }
}

// MARK: - Drag-back helper

enum BTBallPaletteDragBack {
    /// Maps a table-local drop point into the named coordinate space and
    /// returns whether it landed inside the palette frame.
    static func hitPalette(localPoint: CGPoint,
                           sceneFrame: CGRect,
                           paletteFrame: CGRect) -> Bool {
        guard sceneFrame != .zero, paletteFrame != .zero else { return false }
        let point = CGPoint(x: localPoint.x + sceneFrame.minX,
                            y: localPoint.y + sceneFrame.minY)
        return paletteFrame.contains(point)
    }
}
