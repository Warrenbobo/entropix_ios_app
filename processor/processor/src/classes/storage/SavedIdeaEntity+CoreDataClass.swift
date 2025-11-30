//
//  SavedIdeaEntity+CoreDataClass.swift
//  processor
//
//  Core Data entity for storing saved composition ideas
//

import Foundation
import CoreData
import UIKit

@objc(SavedIdeaEntity)
public class SavedIdeaEntity: NSManagedObject {
    
    /// Convert to GalleryItem
    func toGalleryItem() -> GalleryItem? {
        guard let id = self.id else { return nil }
        
        // Try to load image from path first, then from data
        var image: UIImage?
        if let imagePath = self.imagePath {
            image = UIImage(contentsOfFile: imagePath)
        }
        
        if image == nil, let imageData = self.imageData {
            image = UIImage(data: imageData)
        }
        
        // If still no image, try thumbnail
        if image == nil, let thumbnailData = self.thumbnailData {
            image = UIImage(data: thumbnailData)
        }
        
        return GalleryItem(
            image: image,
            title: self.sceneType,
            id: id,
            isLivePhoto: false,  // Saved ideas are not Live Photos
            livePhotoVideoPath: nil
        )
    }
    
    /// Convert to LMCompositionSuggestion
    func toCompositionSuggestion() -> LMCompositionSuggestion {
        // Parse bounding box from JSON string
        var boundingBox: BoundingBox? = nil
        if let boxData = self.personBoundingBoxData,
           let data = boxData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            boundingBox = BoundingBox(
                x: json["x"] as? Double ?? 0,
                y: json["y"] as? Double ?? 0,
                width: json["width"] as? Double ?? 0,
                height: json["height"] as? Double ?? 0
            )
        }
        
        return LMCompositionSuggestion(
            id: self.id ?? UUID().uuidString,
            sceneType: self.sceneType ?? "",
            source: self.source ?? "",
            ready: true,
            imageUrl: self.imageUrl,
            similarImageUrl: nil,
            rank: Int(self.rank),
            score: self.confidence,
            modelVersion: "",
            personBoundingBox: boundingBox,
            aspectRatio: 1
        )
    }
}
