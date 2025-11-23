//
//  SavedIdeaEntity+CoreDataProperties.swift
//  processor
//
//  Core Data properties for SavedIdeaEntity
//

import Foundation
import CoreData

extension SavedIdeaEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SavedIdeaEntity> {
        return NSFetchRequest<SavedIdeaEntity>(entityName: "SavedIdeaEntity")
    }
    
    @NSManaged public var id: String?
    @NSManaged public var serverId: String?
    @NSManaged public var userId: String?
    @NSManaged public var sceneType: String?
    @NSManaged public var source: String?
    @NSManaged public var imageUrl: String?
    @NSManaged public var imagePath: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var personBoundingBoxData: String?
    @NSManaged public var rank: Int32
    @NSManaged public var confidence: Double
    @NSManaged public var savedDate: Date?
    @NSManaged public var isSynced: Bool
    @NSManaged public var isMarkedDeleted: Bool
}

extension SavedIdeaEntity: Identifiable {
    // Identifiable conformance is automatic via @NSManaged id property
}
