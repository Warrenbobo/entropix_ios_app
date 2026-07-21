//
//  LMAgentRequestLogStore.swift
//  processor
//

import UIKit

extension Notification.Name {
    static let agentRequestLogStoreDidChange = Notification.Name("agentRequestLogStoreDidChange")
}

/// Distinguishes full snapshot rebuilds from high-frequency score ticks.
enum LMAgentRequestLogChangeKind: String {
    case full
    case scoreOnly

    static let userInfoKey = "kind"
}

/// In-memory store for the agent request log screen.
final class LMAgentRequestLogStore {
    static let shared = LMAgentRequestLogStore()

    private let lock = NSLock()
    private var snapshotStorage: LMAgentRequestLogSnapshot?
    private var inspireMeFrameStorage: LMInspireMeLogFrame?
    private var inspireMeEva02Storage: LMInspireMeEva02LogInfo?
    private var latestScoreStorage: LMCompositionScore?
    /// True while `LMAgentRequestLogPage` is on screen — gates high-frequency score notifications.
    private var logPageVisible = false
    private var lastScoreNotifyAt: CFAbsoluteTime = 0
    /// Minimum interval between score-only UI notifies while the Log page is visible.
    private let scoreNotifyMinInterval: TimeInterval = 0.5

    private init() {}

    var snapshot: LMAgentRequestLogSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshotStorage
    }

    var inspireMeFrame: LMInspireMeLogFrame? {
        lock.lock()
        defer { lock.unlock() }
        return inspireMeFrameStorage
    }

    var inspireMeEva02: LMInspireMeEva02LogInfo? {
        lock.lock()
        defer { lock.unlock() }
        return inspireMeEva02Storage
    }

    var latestScore: LMCompositionScore? {
        lock.lock()
        defer { lock.unlock() }
        return latestScoreStorage
    }

    /**
     Marks whether the Agent request log page is currently visible.

     High-frequency score updates only post UI notifications while visible.
     */
    func setLogPageVisible(_ visible: Bool) {
        lock.lock()
        logPageVisible = visible
        lock.unlock()
    }

    func setSnapshot(_ snapshot: LMAgentRequestLogSnapshot) {
        lock.lock()
        snapshotStorage = snapshot
        lock.unlock()
        notifyChanged(kind: .full)
    }

    func patchSnapshotResponse(expectedRound: Int, response: LMAgentLlmResponseRecord) {
        lock.lock()
        guard var current = snapshotStorage, current.round == expectedRound else {
            lock.unlock()
            return
        }
        current.llmResponse = response
        snapshotStorage = current
        lock.unlock()
        notifyChanged(kind: .full)
    }

    func setInspireMeFrame(_ frame: LMInspireMeLogFrame) {
        lock.lock()
        inspireMeFrameStorage = frame
        lock.unlock()
        notifyChanged(kind: .full)
    }

    func setInspireMeEva02(_ info: LMInspireMeEva02LogInfo) {
        lock.lock()
        inspireMeEva02Storage = info
        lock.unlock()
        notifyChanged(kind: .full)
    }

    /**
     Updates the latest live score.

     Always stores the value. Posts a UI notification only when the Log page is visible,
     throttled to avoid main-thread rebuild pressure.
     */
    func updateLatestScore(_ score: LMCompositionScore?) {
        lock.lock()
        latestScoreStorage = score
        let shouldNotify = logPageVisible
        let now = CFAbsoluteTimeGetCurrent()
        let throttled = shouldNotify && (now - lastScoreNotifyAt) >= scoreNotifyMinInterval
        if throttled {
            lastScoreNotifyAt = now
        }
        lock.unlock()

        guard throttled else { return }
        notifyChanged(kind: .scoreOnly)
    }

    /// UI-only 90° clockwise rotation for reference image experiments.
    func rotateReferenceClockwise() {
        lock.lock()
        guard var current = snapshotStorage else {
            lock.unlock()
            return
        }
        let rotated = Self.rotateImageClockwise(current.referenceImage)
        current = LMAgentRequestLogSnapshot(
            recordedAtMs: current.recordedAtMs,
            round: current.round,
            source: current.source,
            deviceOrientation: current.deviceOrientation,
            rawReferenceSize: current.rawReferenceSize,
            rawCameraViewSize: current.rawCameraViewSize,
            submittedReferenceSize: Self.sizeLabel(rotated),
            submittedCameraViewSize: current.submittedCameraViewSize,
            referenceImage: rotated,
            cameraViewImage: current.cameraViewImage,
            systemPrompt: current.systemPrompt,
            userPrompt: current.userPrompt,
            requestJsonPreview: current.requestJsonPreview,
            compositionScore: current.compositionScore,
            llmResponse: current.llmResponse
        )
        snapshotStorage = current
        lock.unlock()
        notifyChanged(kind: .full)
    }

    /// UI-only 90° clockwise rotation for camera view experiments.
    func rotateCameraViewClockwise() {
        lock.lock()
        guard var current = snapshotStorage else {
            lock.unlock()
            return
        }
        let rotated = Self.rotateImageClockwise(current.cameraViewImage)
        current = LMAgentRequestLogSnapshot(
            recordedAtMs: current.recordedAtMs,
            round: current.round,
            source: current.source,
            deviceOrientation: current.deviceOrientation,
            rawReferenceSize: current.rawReferenceSize,
            rawCameraViewSize: current.rawCameraViewSize,
            submittedReferenceSize: current.submittedReferenceSize,
            submittedCameraViewSize: Self.sizeLabel(rotated),
            referenceImage: current.referenceImage,
            cameraViewImage: rotated,
            systemPrompt: current.systemPrompt,
            userPrompt: current.userPrompt,
            requestJsonPreview: current.requestJsonPreview,
            compositionScore: current.compositionScore,
            llmResponse: current.llmResponse
        )
        snapshotStorage = current
        lock.unlock()
        notifyChanged(kind: .full)
    }

    func clear() {
        lock.lock()
        snapshotStorage = nil
        inspireMeFrameStorage = nil
        inspireMeEva02Storage = nil
        latestScoreStorage = nil
        lock.unlock()
        notifyChanged(kind: .full)
    }

    private func notifyChanged(kind: LMAgentRequestLogChangeKind) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .agentRequestLogStoreDidChange,
                object: nil,
                userInfo: [LMAgentRequestLogChangeKind.userInfoKey: kind.rawValue]
            )
        }
    }

    private static func sizeLabel(_ image: UIImage) -> String {
        "\(Int(image.size.width))x\(Int(image.size.height))"
    }

    private static func rotateImageClockwise(_ image: UIImage) -> UIImage {
        let size = CGSize(width: image.size.height, height: image.size.width)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }
}
