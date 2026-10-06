//
//  LMAppVersionComparer.swift
//  processor
//
//  Semver-like MAJOR.MINOR.PATCH compare for App Store update classification.
//

import Foundation

/// Outcome of comparing local marketing version to App Store Lookup version.
enum LMAppUpdateClass: Equatable {
    case none
    case recommend
    case force
}

/// Parses and classifies marketing versions (SPEC: major=force, minor/patch=recommend).
enum LMAppVersionComparer {

    /**
     Parses a marketing version into `(major, minor, patch)`.

     - Missing segments default to `0` (`1.2` → `1.2.0`).
     - Strips prerelease / build suffixes after `-` or `+`.
     - Returns `nil` if the core cannot be parsed as integers.
     */
    static func parse(_ raw: String) -> (Int, Int, Int)? {
        var core = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dash = core.firstIndex(of: "-") {
            core = String(core[..<dash])
        }
        if let plus = core.firstIndex(of: "+") {
            core = String(core[..<plus])
        }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        func intPart(_ index: Int) -> Int? {
            guard index < parts.count else { return 0 }
            let token = parts[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { return 0 }
            return Int(token)
        }

        guard let major = intPart(0),
              let minor = intPart(1),
              let patch = intPart(2) else {
            return nil
        }
        return (major, minor, patch)
    }

    /**
     Classifies store vs local versions.

     - Force when store major &gt; local major.
     - Recommend when same major and store is ahead on minor or patch.
     - None when equal, local ahead, or unparseable.
     */
    static func classify(local: String, store: String) -> LMAppUpdateClass {
        guard let localParts = parse(local), let storeParts = parse(store) else {
            LMLogger.log("⚠️ App version compare failed: local=\(local) store=\(store)")
            return .none
        }

        let (lm, lmin, lp) = localParts
        let (sm, smin, sp) = storeParts

        if sm > lm {
            return .force
        }
        if sm < lm {
            return .none
        }
        // Same major
        if smin > lmin {
            return .recommend
        }
        if smin < lmin {
            return .none
        }
        // Same major.minor
        if sp > lp {
            return .recommend
        }
        return .none
    }
}
