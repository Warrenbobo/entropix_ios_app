//
//  LMAppStoreLookupService.swift
//  processor
//
//  Apple iTunes Lookup for App Store marketing version metadata.
//

import Foundation

/// App Store Lookup payload used for update UI (never scrapes apps.apple.com HTML).
struct LMAppStoreLookupResult: Equatable {
    var storeVersion: String
    var trackViewUrl: String?
    var releaseNotes: String?
    var bundleId: String?
}

/// Fetches App Store listing metadata via `https://itunes.apple.com/lookup`.
enum LMAppStoreLookupService {

    private static let lookupBase = "https://itunes.apple.com/lookup"

    /**
     Looks up the live App Store version for `AppConfigs.AppStore.appID`.

     - Parameter completion: Called on a background queue with result or `nil` on failure.
     */
    static func fetch(completion: @escaping (LMAppStoreLookupResult?) -> Void) {
        var components = URLComponents(string: lookupBase)
        var items = [URLQueryItem(name: "id", value: AppConfigs.AppStore.appID)]
        if let region = Locale.current.region?.identifier, !region.isEmpty {
            items.append(URLQueryItem(name: "country", value: region.lowercased()))
        }
        components?.queryItems = items

        guard let url = components?.url else {
            LMLogger.log("⚠️ App Store Lookup URL build failed")
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error {
                LMLogger.log("⚠️ App Store Lookup network error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                LMLogger.log("⚠️ App Store Lookup bad HTTP status")
                completion(nil)
                return
            }
            guard let data else {
                completion(nil)
                return
            }
            completion(decodeLookup(data))
        }
        task.resume()
    }

    private static func decodeLookup(_ data: Data) -> LMAppStoreLookupResult? {
        struct LookupResponse: Decodable {
            let resultCount: Int
            let results: [LookupItem]
        }
        struct LookupItem: Decodable {
            let version: String?
            let trackViewUrl: String?
            let releaseNotes: String?
            let bundleId: String?
        }

        do {
            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard decoded.resultCount > 0,
                  let first = decoded.results.first,
                  let version = first.version?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !version.isEmpty else {
                LMLogger.log("⚠️ App Store Lookup empty results")
                return nil
            }

            if let bundleId = first.bundleId,
               let localBundle = Bundle.main.bundleIdentifier,
               bundleId != localBundle {
                LMLogger.log("⚠️ App Store Lookup bundleId mismatch: store=\(bundleId) local=\(localBundle)")
            }

            return LMAppStoreLookupResult(
                storeVersion: version,
                trackViewUrl: first.trackViewUrl,
                releaseNotes: first.releaseNotes,
                bundleId: first.bundleId
            )
        } catch {
            LMLogger.log("⚠️ App Store Lookup decode failed: \(error.localizedDescription)")
            return nil
        }
    }
}
