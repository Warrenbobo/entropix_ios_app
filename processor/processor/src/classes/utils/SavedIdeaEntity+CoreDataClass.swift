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
