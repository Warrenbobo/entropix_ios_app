//
//  LMCameraGuideManager.swift
//  processor
//
//  Camera tutorial decks: first-time Journey + Mode help.
//

import Foundation

/// Which tutorial deck is being presented.
enum LMCameraTutorialDeck: Equatable {
    case journey
    case modeHelp

    var stepCount: Int {
        switch self {
        case .journey: return LMCameraJourneyStep.allCases.count
        case .modeHelp: return LMCameraModeHelpStep.allCases.count
        }
    }
}

/// First-time product journey: Find Spot → Templates → Live Coaching.
enum LMCameraJourneyStep: Int, CaseIterable {
    case findSpot = 1
    case templates
    case coaching

    var index: Int { rawValue }

    var title: String {
        switch self {
        case .findSpot: return LMText.camera.tutorialJourneyFindSpotTitle
        case .templates: return LMText.camera.tutorialJourneyTemplatesTitle
        case .coaching: return LMText.camera.tutorialJourneyCoachingTitle
        }
    }

    var description: String {
        switch self {
        case .findSpot: return LMText.camera.tutorialJourneyFindSpotDescription
        case .templates: return LMText.camera.tutorialJourneyTemplatesDescription
        case .coaching: return LMText.camera.tutorialJourneyCoachingDescription
        }
    }

    var assetName: String {
        switch self {
        case .findSpot: return AppConfigs.Assets.tutorialJourneyFindSpot
        case .templates: return AppConfigs.Assets.tutorialJourneyTemplates
        case .coaching: return AppConfigs.Assets.tutorialJourneyCoaching
        }
    }

    var isLast: Bool { self == .coaching }

    var showsPreviousButton: Bool {
        self == .templates || self == .coaching
    }

    var next: LMCameraJourneyStep? {
        LMCameraJourneyStep(rawValue: rawValue + 1)
    }

    var previous: LMCameraJourneyStep? {
        LMCameraJourneyStep(rawValue: rawValue - 1)
    }
}

/// Mode-chip `?` help: mode deck overview + Find Spot vs Get Template.
enum LMCameraModeHelpStep: Int, CaseIterable {
    case modeDeck = 1
    case spotVsTemplate

    var index: Int { rawValue }

    var title: String {
        switch self {
        case .modeDeck: return LMText.camera.tutorialModeDeckTitle
        case .spotVsTemplate: return LMText.camera.tutorialModeContrastTitle
        }
    }

    var description: String {
        switch self {
        case .modeDeck: return LMText.camera.tutorialModeDeckDescription
        case .spotVsTemplate: return LMText.camera.tutorialModeContrastDescription
        }
    }

    var isLast: Bool { self == .spotVsTemplate }

    var showsPreviousButton: Bool { self == .spotVsTemplate }

    var next: LMCameraModeHelpStep? {
        LMCameraModeHelpStep(rawValue: rawValue + 1)
    }

    var previous: LMCameraModeHelpStep? {
        LMCameraModeHelpStep(rawValue: rawValue - 1)
    }
}

/// Active step inside a presented deck.
enum LMCameraTutorialStep: Equatable {
    case journey(LMCameraJourneyStep)
    case modeHelp(LMCameraModeHelpStep)

    var deck: LMCameraTutorialDeck {
        switch self {
        case .journey: return .journey
        case .modeHelp: return .modeHelp
        }
    }

    var index: Int {
        switch self {
        case .journey(let step): return step.index
        case .modeHelp(let step): return step.index
        }
    }

    var stepCount: Int { deck.stepCount }

    var title: String {
        switch self {
        case .journey(let step): return step.title
        case .modeHelp(let step): return step.title
        }
    }

    var description: String {
        switch self {
        case .journey(let step): return step.description
        case .modeHelp(let step): return step.description
        }
    }

    var isLast: Bool {
        switch self {
        case .journey(let step): return step.isLast
        case .modeHelp(let step): return step.isLast
        }
    }

    var showsPreviousButton: Bool {
        switch self {
        case .journey(let step): return step.showsPreviousButton
        case .modeHelp(let step): return step.showsPreviousButton
        }
    }

    var primaryButtonTitle: String {
        isLast ? LMText.camera.tutorialGotIt : LMText.camera.tutorialNext
    }

    var next: LMCameraTutorialStep? {
        switch self {
        case .journey(let step):
            return step.next.map { .journey($0) }
        case .modeHelp(let step):
            return step.next.map { .modeHelp($0) }
        }
    }

    var previous: LMCameraTutorialStep? {
        switch self {
        case .journey(let step):
            return step.previous.map { .journey($0) }
        case .modeHelp(let step):
            return step.previous.map { .modeHelp($0) }
        }
    }

    static func first(of deck: LMCameraTutorialDeck) -> LMCameraTutorialStep {
        switch deck {
        case .journey: return .journey(.findSpot)
        case .modeHelp: return .modeHelp(.modeDeck)
        }
    }
}

/// Completes / resets the first-time camera walkthrough flag.
final class LMCameraGuideManager {

    static let shared = LMCameraGuideManager()

    private let userDefaults = UserDefaults.standard
    private let tutorialCompletedKey = "hasCompletedCameraWalkthrough"

    private init() {}

    func hasCompletedTutorial() -> Bool {
        userDefaults.bool(forKey: tutorialCompletedKey)
    }

    func shouldShowTutorialAutomatically() -> Bool {
        !hasCompletedTutorial()
    }

    func markTutorialCompleted() {
        userDefaults.set(true, forKey: tutorialCompletedKey)
        userDefaults.synchronize()
        LMLogger.log("✅ [Tutorial] Marked journey tutorial as completed")
    }

    func resetTutorial() {
        userDefaults.removeObject(forKey: tutorialCompletedKey)
        userDefaults.synchronize()
        LMLogger.log("🔄 [Tutorial] Journey tutorial reset")
    }
}
