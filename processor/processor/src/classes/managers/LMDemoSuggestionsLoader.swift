//
//  LMDemoSuggestionsLoader.swift
//  processor
//

import Foundation

/// Loads bundled demo suggestion images for offline Inspire Me (Android `loadDemoSuggestions` parity).
enum LMDemoSuggestionsLoader {

    private static let imageExtensions = ["jpg", "jpeg", "png"]

    /// Returns demo suggestions from `demo_suggestions/` in the app bundle, sorted alphabetically.
    static func loadSuggestions() -> [LMCompositionSuggestion] {
        let dir = AppConfigs.demoSuggestionsDir
        var fileURLs: [URL] = []

        for ext in imageExtensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: dir) {
                fileURLs.append(contentsOf: urls)
            }
        }

        let sorted = fileURLs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        return sorted.enumerated().map { index, url in
            LMCompositionSuggestion(
                id: "demo_\(index)",
                sceneType: nil,
                source: "demo",
                ready: true,
                imageUrl: url.absoluteString,
                width: nil,
                height: nil,
                rank: index,
                score: nil
            )
        }
    }
}
