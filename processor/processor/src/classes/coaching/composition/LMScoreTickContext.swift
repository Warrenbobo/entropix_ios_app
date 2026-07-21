//
//  LMScoreTickContext.swift
//  processor
//
//  Per-tick ephemeral ownership for composition scoring (plan §9).
//

import Foundation

/// Owns camera-side ephemeral artifacts for one `analyze()` call; released every tick.
final class LMScoreTickContext {
    var cameraHumanSnapshot: LMHumanFrameSnapshot?
    var cameraDepth: LMDepthMap?
    /// PiDiNet edge map for the camera frame (T1); cleared each tick.
    var cameraEdgeMap: [Float]?
    /// U2-Netp saliency mask for the camera frame (T1); cleared each tick.
    var cameraSaliencyMask: [Float]?
    var debugLabel: String?

    /**
     Clears tick-ephemeral fields. Call via `defer` at end of every score tick.

     - Note: Does not clear reference (T2) or model (T3) caches.
     */
    func releaseEphemeral() {
        cameraHumanSnapshot = nil
        cameraDepth = nil
        cameraEdgeMap = nil
        cameraSaliencyMask = nil
#if DEBUG
        if let debugLabel {
            LMLogger.log("ScoreTickContext.releaseEphemeral \(debugLabel)")
        }
#endif
        debugLabel = nil
    }
}

/// Low-resolution depth map used for human-depth scoring (not full-camera resolution).
struct LMDepthMap: Sendable {
    let values: [Float]
    let width: Int
    let height: Int

    var count: Int { values.count }
}
