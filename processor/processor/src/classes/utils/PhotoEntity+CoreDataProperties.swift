//
//  PhotoEntity+CoreDataProperties.swift
//  processor
//
//  Core Data properties for PhotoEntity
//

import Foundation
import CoreData

extension PhotoEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PhotoEntity> {
        return NSFetchRequest<PhotoEntity>(entityName: "PhotoEntity")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var serverId: String?
    @NSManaged public var userId: String?
    @NSManaged public var title: String?
    @NSManaged public var imagePath: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var referenceImagePath: String?
    @NSManaged public var referenceImageData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var capturedDate: Date?
    @NSManaged public var isSynced: Bool
    @NSManaged public var isMarkedDeleted: Bool
    @NSManaged public var isLivePhoto: Bool
    @NSManaged public var livePhotoVideoPath: String?
}

extension PhotoEntity: Identifiable {
    // Identifiable conformance is automatic via @NSManaged id property
}
