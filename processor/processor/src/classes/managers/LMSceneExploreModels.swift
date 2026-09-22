//
//  LMSceneExploreModels.swift
//  processor
//
//  Scene Explore spot / session models (parity SPEC §5).
//

import UIKit

/// One spotting position returned by Scene Explore VLM.
struct LMSceneExploreSpot: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var reason: String
    /// Normalized bbox as **xywh** [x, y, w, h] in 0…1 (converted from Android xyxy if needed).
    var bbox: [CGFloat]
    var safetyWarning: String?
    /// Model-facing photographer position for Path A Inspire (not shown on Find Spot cards).
    var cameraInstruction: String?

    enum CodingKeys: String, CodingKey {
        case id, name, reason, bbox
        case safetyWarning = "safety_warning"
        case cameraInstruction = "camera_instruction"
    }

    /// Normalized rectangle in unit image space.
    var normalizedRect: CGRect {
        guard bbox.count >= 4 else { return .zero }
        return CGRect(x: bbox[0], y: bbox[1], width: bbox[2], height: bbox[3])
    }

    var center: CGPoint {
        let rect = normalizedRect
        guard rect.width > 0, rect.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: rect.midX, y: rect.midY)
    }
}

/// Parsed Scene Explore VLM payload (spots + optional wide-scene flag).
struct LMSceneExploreParseResult {
    var spots: [LMSceneExploreSpot]
    var wideScene: Bool
    var declineReason: String?
}

/// Explore session phase.
enum LMExploreSessionPhase: String, Codable {
    case idle
    case processing
    case result
    case suspended
    case ended
}

/// In-memory / persisted Explore session.
final class LMExploreSession {
    let sessionId: String
    var phase: LMExploreSessionPhase
    var freezeFrame: UIImage?
    /// Composite heatmap over freeze frame when `showHeatmap` is true.
    var heatmapImage: UIImage?
    var showHeatmap: Bool
    var wideScene: Bool
    var spots: [LMSceneExploreSpot]
    var selectedSpotId: String?
    var inspireTaskId: String?
    /// Spot ids that already generated templates in this session (Path A shared task).
    var generatedSpotIds: Set<String>
    var coverImagePath: String?
    var createdAt: Date

    init(
        sessionId: String = UUID().uuidString,
        phase: LMExploreSessionPhase = .idle,
        freezeFrame: UIImage? = nil,
        heatmapImage: UIImage? = nil,
        showHeatmap: Bool = false,
        wideScene: Bool = false,
        spots: [LMSceneExploreSpot] = [],
        selectedSpotId: String? = nil,
        inspireTaskId: String? = nil,
        generatedSpotIds: Set<String> = [],
        coverImagePath: String? = nil,
        createdAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.phase = phase
        self.freezeFrame = freezeFrame
        self.heatmapImage = heatmapImage
        self.showHeatmap = showHeatmap
        self.wideScene = wideScene
        self.spots = spots
        self.selectedSpotId = selectedSpotId
        self.inspireTaskId = inspireTaskId
        self.generatedSpotIds = generatedSpotIds
        self.coverImagePath = coverImagePath
        self.createdAt = createdAt
    }

    var selectedSpot: LMSceneExploreSpot? {
        guard let selectedSpotId else { return nil }
        return spots.first { $0.id == selectedSpotId }
    }
}

/// Strategy A history bookmark (cover + Spot JSON; no suggestion tiles).
struct LMSceneHistoryRecord: Codable, Identifiable {
    var id: String
    var createdAt: TimeInterval
    var coverImageRelativePath: String
    var spotsJSON: Data
    var selectedSpotId: String?
    /// Whether heatmap should be regenerated when browsing this record.
    var showHeatmap: Bool

    var spots: [LMSceneExploreSpot] {
        (try? JSONDecoder().decode([LMSceneExploreSpot].self, from: spotsJSON)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, coverImageRelativePath, spotsJSON, selectedSpotId, showHeatmap
    }

    init(
        id: String,
        createdAt: TimeInterval,
        coverImageRelativePath: String,
        spotsJSON: Data,
        selectedSpotId: String?,
        showHeatmap: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.coverImageRelativePath = coverImageRelativePath
        self.spotsJSON = spotsJSON
        self.selectedSpotId = selectedSpotId
        self.showHeatmap = showHeatmap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        createdAt = try c.decode(TimeInterval.self, forKey: .createdAt)
        coverImageRelativePath = try c.decode(String.self, forKey: .coverImageRelativePath)
        spotsJSON = try c.decode(Data.self, forKey: .spotsJSON)
        selectedSpotId = try c.decodeIfPresent(String.self, forKey: .selectedSpotId)
        showHeatmap = try c.decodeIfPresent(Bool.self, forKey: .showHeatmap) ?? true
    }
}
