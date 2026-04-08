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
        
        // Prefer thumbnail first to avoid decoding full-size files during grid loading
        var image: UIImage?
        if let thumbnailData = self.thumbnailData {
            image = UIImage(data: thumbnailData)
        } else if let imageData = self.imageData {
            image = UIImage(data: imageData)
        } else if let imagePath = self.imagePath {
            image = UIImage(contentsOfFile: imagePath)
        }
        
        return GalleryItem(
            image: image,
            title: self.sceneType,
            id: id,
            isLivePhoto: false,  // Saved ideas are not Live Photos
            livePhotoVideoPath: nil,
            imagePath: nil  // Saved ideas don't need original image path
        )
    }
    
    /// Convert to LMCompositionSuggestion
    func toCompositionSuggestion() -> LMCompositionSuggestion {
        return LMCompositionSuggestion(
            id: self.id ?? UUID().uuidString,
            sceneType: self.sceneType ?? "",
            source: self.source ?? "",
            ready: true,
            imageUrl: self.imageUrl,
            width: nil,
            height: nil,
            rank: Int(self.rank),
            score: self.confidence
        )
    }
}
