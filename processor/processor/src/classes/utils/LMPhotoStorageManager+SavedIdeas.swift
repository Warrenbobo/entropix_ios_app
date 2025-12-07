//
//  LMPhotoStorageManager+SavedIdeas.swift
//  processor
//
//  Extension for managing saved composition ideas
//

import Foundation
import CoreData
import UIKit

extension LMPhotoStorageManager {
    
    // MARK: - Save Idea
    
    /// Save a composition suggestion as a saved idea
    /// - Parameters:
    ///   - suggestion: The composition suggestion to save
    ///   - image: Optional image data
    /// - Returns: The saved SavedIdeaEntity or nil if failed
    @discardableResult
    func saveSuggestionAsIdea(suggestion: LMCompositionSuggestion, image: UIImage? = nil) -> SavedIdeaEntity? {
        let ideaId = suggestion.id
        let timestamp = Date()
        
        // Check if already saved
        if let existing = fetchSavedIdea(byId: ideaId) {
            LMLogger.log("💡 Idea already saved with ID: \(ideaId)")
            return existing
        }
        
        // Save image to file if provided
        var imagePath: String?
        if let img = image {
            imagePath = saveIdeaImageToFile(image: img, ideaId: ideaId)
        }
        
        // Generate thumbnail
        var thumbnailData: Data?
        if let img = image {
            thumbnailData = img.jpegData(compressionQuality: 1)
        }
        
        // Create Core Data entity
        let ideaEntity = SavedIdeaEntity(context: context)
        ideaEntity.id = ideaId
        ideaEntity.userId = LMUserManager.shared.currentUser?.userId
        ideaEntity.sceneType = suggestion.sceneType
        ideaEntity.source = suggestion.source
        ideaEntity.imageUrl = suggestion.imageUrl
        ideaEntity.imagePath = imagePath
        ideaEntity.thumbnailData = thumbnailData
        ideaEntity.rank = Int32(suggestion.rank)
        ideaEntity.confidence = suggestion.score ?? 0.0
        ideaEntity.savedDate = timestamp
        ideaEntity.isSynced = false
        ideaEntity.isMarkedDeleted = false
        
        // Save context
        do {
            try context.save()
            LMLogger.log("✅ Saved idea successfully with ID: \(ideaId)")
            return ideaEntity
        } catch {
            LMLogger.log("❌ Failed to save idea to Core Data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Fetch Saved Ideas
    
    /// Fetch all saved ideas for current user
    /// - Returns: Array of SavedIdeaEntity
    func fetchAllSavedIdeas() -> [SavedIdeaEntity] {
        let fetchRequest: NSFetchRequest<SavedIdeaEntity> = SavedIdeaEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "savedDate", ascending: false)]
        
        // Filter by user if logged in
        if let userId = LMUserManager.shared.currentUser?.userId {
            fetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO AND userId == %@", userId)
        }
        
        do {
            let ideas = try context.fetch(fetchRequest)
            LMLogger.log("💡 Fetched \(ideas.count) saved ideas from storage")
            return ideas
        } catch {
            LMLogger.log("❌ Failed to fetch saved ideas: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetch saved idea by ID
    /// - Parameter id: Idea ID
    /// - Returns: SavedIdeaEntity or nil
    func fetchSavedIdea(byId id: String) -> SavedIdeaEntity? {
        let fetchRequest: NSFetchRequest<SavedIdeaEntity> = SavedIdeaEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND isMarkedDeleted == NO", id)
        fetchRequest.fetchLimit = 1
        
        do {
            let ideas = try context.fetch(fetchRequest)
            return ideas.first
        } catch {
            LMLogger.log("❌ Failed to fetch saved idea by ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check if a suggestion is already saved
    /// - Parameter suggestionId: The suggestion ID
    /// - Returns: True if saved, false otherwise
    func isSuggestionSaved(suggestionId: String) -> Bool {
        return fetchSavedIdea(byId: suggestionId) != nil
    }
    
    // MARK: - Delete Saved Idea
    
    /// Delete a saved idea (soft delete)
    /// - Parameter id: Idea ID
    /// - Returns: Success or failure
    @discardableResult
    func deleteSavedIdea(byId id: String) -> Bool {
        guard let idea = fetchSavedIdea(byId: id) else {
            LMLogger.log("❌ Saved idea not found with ID: \(id)")
            return false
        }
        
        // Soft delete
        idea.isMarkedDeleted = true
        
        do {
            try context.save()
            LMLogger.log("✅ Saved idea marked as deleted: \(id)")
            return true
        } catch {
            LMLogger.log("❌ Failed to delete saved idea: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Permanently delete a saved idea and its files
    /// - Parameter id: Idea ID
    /// - Returns: Success or failure
    @discardableResult
    func permanentlyDeleteSavedIdea(byId id: String) -> Bool {
        guard let idea = fetchSavedIdea(byId: id) else {
            LMLogger.log("❌ Saved idea not found with ID: \(id)")
            return false
        }
        
        // Delete image files
        if let imagePath = idea.imagePath {
            deleteFile(at: imagePath)
        }
        
        // Delete from Core Data
        context.delete(idea)
        
        do {
            try context.save()
            LMLogger.log("✅ Saved idea permanently deleted: \(id)")
            return true
        } catch {
            LMLogger.log("❌ Failed to permanently delete saved idea: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveIdeaImageToFile(image: UIImage, ideaId: String) -> String? {
        let fileName = "\(ideaId)_idea.jpg"
        let filePath = photosDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            LMLogger.log("❌ Failed to convert idea image to JPEG data")
            return nil
        }
        
        do {
            try imageData.write(to: filePath)
            LMLogger.log("✅ Idea image saved to: \(filePath.path)")
            return filePath.path
        } catch {
            LMLogger.log("❌ Failed to save idea image to file: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Sync Status
    
    /// Mark saved idea as synced with server
    /// - Parameters:
    ///   - id: Idea ID
    ///   - serverId: Server-assigned ID
    @discardableResult
    func markSavedIdeaAsSynced(id: String, serverId: String) -> Bool {
        guard let idea = fetchSavedIdea(byId: id) else {
            return false
        }
        
        idea.isSynced = true
        idea.serverId = serverId
        
        do {
            try context.save()
            LMLogger.log("✅ Saved idea marked as synced: \(id)")
            return true
        } catch {
            LMLogger.log("❌ Failed to mark saved idea as synced: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get unsynced saved ideas
    /// - Returns: Array of SavedIdeaEntity that need to be synced
    func fetchUnsyncedSavedIdeas() -> [SavedIdeaEntity] {
        let fetchRequest: NSFetchRequest<SavedIdeaEntity> = SavedIdeaEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO AND isMarkedDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "savedDate", ascending: true)]
        
        do {
            let ideas = try context.fetch(fetchRequest)
            LMLogger.log("📤 Found \(ideas.count) unsynced saved ideas")
            return ideas
        } catch {
            LMLogger.log("❌ Failed to fetch unsynced saved ideas: \(error.localizedDescription)")
            return []
        }
    }
}
