//
//  LMInspirePromptBuilder.swift
//  processor
//
//  FREE_COMPOSITION vs FIXED_CAMERA prompts (Inspire Me / Find Spot Revision SPEC).
//

import Foundation

/// Inspire Me generation mode presented to Gemini.
enum LMInspireGenerationMode: String, Sendable {
    /// Normal Inspire Me and Path B — free compositions from the live/current frame.
    case freeComposition = "FREE_COMPOSITION"
    /// Path A — four variations from one fixed photographer position.
    case fixedCamera = "FIXED_CAMERA"
}

/**
 Assembles Inspire Me prompts per product mode.

 Authority: Inspire Me & Find Spot Revision SPEC §8 / §9. Bundled `gemini_inspire_prompt.txt`
 remains a short fallback only.
 */
enum LMInspirePromptBuilder {

    static let subjectLine =
        "Young Chinese traveler in modest, fashionable daily wear."

    /**
     Builds the full text prompt for a Direct Gemini Inspire request.

     - Parameters:
       - mode: FREE vs FIXED camera.
       - aspectRatio: Snapped panel aspect (e.g. `3:4`).
       - spot: Required context for `.fixedCamera`; ignored for free mode.
     */
    static func build(
        mode: LMInspireGenerationMode,
        aspectRatio: String,
        spot: LMSceneExploreSpot? = nil
    ) -> String {
        switch mode {
        case .freeComposition:
            return freeCompositionPrompt(aspectRatio: aspectRatio)
        case .fixedCamera:
            return fixedCameraPrompt(aspectRatio: aspectRatio, spot: spot)
        }
    }

    // MARK: - FREE_COMPOSITION (SPEC §8)

    private static func freeCompositionPrompt(aspectRatio: String) -> String {
        """
        Create 4 portrait composition ideas for the provided scene, then generate them as one photorealistic 2×2 contact sheet.

        Subject:
        \(subjectLine)

        PLANNING
        Write exactly 4 short composition plans.
        For each, specify only:
        - shot size,
        - subject placement,
        - pose/action.

        Use only physically possible space and objects visible in the reference scene.
        One line per plan. No explanation paragraphs.

        IMAGE
        Generate the 4 planned compositions.

        Preserve the reference scene's architecture, lighting, perspective, and environmental logic.
        Subject interaction, perspective, and shadows must be realistic.

        OUTPUT
        Return exactly one 2×2 image containing four equal panels.
        Do not return four separate images.
        Panel aspect ratio: \(aspectRatio).
        """
    }

    // MARK: - FIXED_CAMERA (SPEC §9)

    private static func fixedCameraPrompt(
        aspectRatio: String,
        spot: LMSceneExploreSpot?
    ) -> String {
        let cameraBlock = cameraPositionBlock(for: spot)
        return """
        Create 4 portrait composition variations from ONE FIXED CAMERA POSITION, then generate them as one photorealistic 2×2 contact sheet.

        CAMERA POSITION — HARD CONSTRAINT
        \(cameraBlock)

        This describes the photographer's physical camera location.
        It is NOT a subject location and NOT merely an object that should appear prominently.

        All 4 panels must use this same selected shooting viewpoint.
        Do not move the photographer to another position.

        PLANNING
        Write exactly 4 short composition plans from this fixed viewpoint.

        For each, specify only:
        - shot size,
        - subject placement,
        - pose/action.

        The four plans may vary framing, crop, subject position, pose, and action.
        They must NOT vary the physical camera position.
        One line per plan. No explanation paragraphs.

        Subject:
        \(subjectLine)

        IMAGE
        Generate the 4 planned variations from the same selected camera position.

        Use only physically possible space and objects visible in the reference scene.
        Preserve the scene's architecture, lighting, perspective, and environmental relationships.
        Keep perspective and shadows realistic.

        OUTPUT
        Return exactly one 2×2 image containing four equal panels.
        Do not return four separate images.
        Panel aspect ratio: \(aspectRatio).
        """
    }

    /**
     SPEC §5.2 / §5.4: prefer `camera_instruction`; otherwise reinterpret name + reason as position.
     */
    private static func cameraPositionBlock(for spot: LMSceneExploreSpot?) -> String {
        guard let spot else {
            return """
            Selected shooting position: (unknown).
            Treat the selected Find Spot as the photographer's physical camera location, not an object that must become the main visual subject.
            """
        }
        if let instruction = spot.cameraInstruction?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !instruction.isEmpty {
            return """
            Selected shooting position:
            \(instruction)

            Spot:
            \(spot.name)

            Context:
            \(spot.reason)
            """
        }
        return """
        Selected shooting position: \(spot.name).
        Reason/context: \(spot.reason).
        Treat this as the photographer's physical camera location, not an object that must become the main visual subject.
        """
    }
}
