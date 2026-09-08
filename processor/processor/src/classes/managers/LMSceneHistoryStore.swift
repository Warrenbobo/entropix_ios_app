//
//  LMSceneHistoryStore.swift
//  processor
//
//  Strategy A Scene History persistence (cover + Spot JSON).
//

import UIKit

/// Persists ended Explore sessions for Mine → Scene History.
enum LMSceneHistoryStore {
    private static let indexKey = "scene_history_index_v1"
    private static let folderName = "scene_history"

    /// All history records, newest first.
    static func loadAll() -> [LMSceneHistoryRecord] {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              let records = try? JSONDecoder().decode([LMSceneHistoryRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    /// Appends a history bookmark from an ended Explore session.
    @discardableResult
    static func save(session: LMExploreSession) -> LMSceneHistoryRecord? {
        guard let frame = session.freezeFrame,
              let spotsData = try? JSONEncoder().encode(session.spots) else {
            return nil
        }
        let id = session.sessionId
        let relative = "\(folderName)/\(id).jpg"
        guard let url = absoluteURL(for: relative),
              let jpeg = frame.jpegData(compressionQuality: 0.85) else {
            return nil
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try jpeg.write(to: url, options: .atomic)
        } catch {
            LMLogger.log("⚠️ Scene history cover save failed: \(error.localizedDescription)")
            return nil
        }

        let record = LMSceneHistoryRecord(
            id: id,
            createdAt: session.createdAt.timeIntervalSince1970,
            coverImageRelativePath: relative,
            spotsJSON: spotsData,
            selectedSpotId: session.selectedSpotId,
            showHeatmap: session.showHeatmap
        )
        var all = loadAll().filter { $0.id != id }
        all.insert(record, at: 0)
        if let encoded = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(encoded, forKey: indexKey)
        }
        LMLogger.log("💾 Scene history saved id=\(id) spots=\(session.spots.count)")
        return record
    }

    /// Loads cover image for a history record.
    static func loadCover(for record: LMSceneHistoryRecord) -> UIImage? {
        guard let url = absoluteURL(for: record.coverImageRelativePath),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    private static func absoluteURL(for relative: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(relative)
    }
}
