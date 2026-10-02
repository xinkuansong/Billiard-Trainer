import Foundation

/// Scene-wide world layout anchors. Mirrors the reference codebase's
/// `SceneLayout` from `01.billiard_app/BilliardTrainer/Utilities/Constants/PhysicsConstants.swift`,
/// trimmed to what the angle-training scene actually needs.
enum BTSceneLayout {
    /// World Y at which the floor sits. The table model is offset upwards so its
    /// playing surface ends up at `BTTablePhysics.surfaceY`.
    static let groundLevelY: Float = 0
}

/// Physical / geometric anchors of the table. Single source of truth for the
/// vertical ladder used by `AngleTrainingScene`, `TableModelLoader`, the camera
/// rig, and the cue stick.
enum BTTablePhysics {
    /// Distance from the floor to the playing surface.
    static let height: Float = 0.80

    /// Cushion (rail nose) height above the playing surface. Used by both the
    /// table-model scaler (to derive `surfaceY` from the model's bounding box)
    /// and the cue stick (to compute the rail-clearance pitch).
    static let cushionHeight: Float = 0.037

    /// Wood-frame thickness measured from cushion outer edge to wood outer edge.
    /// Used by the model scaler to compute the target outer dimensions.
    static let cushionThickness: Float = 0.05

    /// World-space Y of the playing surface (top of the cloth).
    static var surfaceY: Float { BTSceneLayout.groundLevelY + height }
}
