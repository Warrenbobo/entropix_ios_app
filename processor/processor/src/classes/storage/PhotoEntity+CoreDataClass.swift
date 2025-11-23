//
//  PhotoEntity+CoreDataClass.swift
//  processor
//
//  Core Data entity for storing photos
//

import Foundation
import CoreData
import UIKit

@objc(PhotoEntity)
public class PhotoEntity: NSManagedObject {
    
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
            title: self.title,
            id: id
        )
    }
}
