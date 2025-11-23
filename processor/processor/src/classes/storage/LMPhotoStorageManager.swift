//
//  LMPhotoStorageManager.swift
//  processor
//
//  Manager for photo storage using CoreData
//

import Foundation
import CoreData
import UIKit

class LMPhotoStorageManager {
    
    // MARK: - Singleton
    static let shared = LMPhotoStorageManager()
    
    private init() {
        setupDocumentsDirectory()
    }
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "processor")
        container.loadPersistentStores { description, error in
            if let error = error {
                LMLogger.log("❌ Core Data failed to load: \(error.localizedDescription)")
                fatalError("Unresolved error \(error)")
            }
            LMLogger.log("✅ Core Data loaded successfully")
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Documents Directory
    lazy var photosDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosPath = documentsPath.appendingPathComponent("Photos", isDirectory: true)
        return photosPath
    }()
    
    private lazy var thumbnailsDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbnailsPath = documentsPath.appendingPathComponent("Thumbnails", isDirectory: true)
        return thumbnailsPath
    }()
    
    private func setupDocumentsDirectory() {
        let fileManager = FileManager.default
        
        // Create Photos directory
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            do {
                try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
                LMLogger.log("📁 Created Photos directory at: \(photosDirectory.path)")
            } catch {
                LMLogger.log("❌ Failed to create Photos directory: \(error.localizedDescription)")
            }
        }
        
        // Create Thumbnails directory
        if !fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            do {
                try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
                LMLogger.log("📁 Created Thumbnails directory at: \(thumbnailsDirectory.path)")
            } catch {
                LMLogger.log("❌ Failed to create Thumbnails directory: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Save Photo
    
    /// Save a photo to local storage
    /// - Parameters:
    ///   - image: The captured photo
    ///   - referenceImage: Optional reference composition image
    ///   - title: Optional title
    /// - Returns: The saved PhotoEntity or nil if failed
    @discardableResult
    func savePhoto(image: UIImage, referenceImage: UIImage? = nil, title: String? = nil) -> PhotoEntity? {
        let photoId = UUID().uuidString
        let timestamp = Date()
        
        // Save main image to file
        guard let imagePath = saveImageToFile(image: image, photoId: photoId, isReference: false) else {
            LMLogger.log("❌ Failed to save main image to file")
            return nil
        }
        
        // Save reference image if provided
        var referenceImagePath: String?
        if let refImage = referenceImage {
            referenceImagePath = saveImageToFile(image: refImage, photoId: photoId, isReference: true)
        }
        
        // Generate thumbnail
        let thumbnail = generateThumbnail(from: image)
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.7)
        
        // Create Core Data entity
        let photoEntity = PhotoEntity(context: context)
        photoEntity.id = photoId
        photoEntity.userId = LMUserManager.shared.currentUser?.userId
        photoEntity.title = title
        photoEntity.imagePath = imagePath
        photoEntity.referenceImagePath = referenceImagePath
        photoEntity.thumbnailData = thumbnailData
        photoEntity.capturedDate = timestamp
        photoEntity.isSynced = false
        photoEntity.isMarkedDeleted = false
        
        // Save context
        do {
            try context.save()
            LMLogger.log("✅ Photo saved successfully with ID: \(photoId)")
            return photoEntity
        } catch {
            LMLogger.log("❌ Failed to save photo to Core Data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Fetch Photos
    
    /// Fetch all photos for current user
    /// - Returns: Array of PhotoEntity
    func fetchAllPhotos() -> [PhotoEntity] {
        let fetchRequest: NSFetchRequest<PhotoEntity> = PhotoEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "capturedDate", ascending: false)]
        
        // Filter by user if logged in
        if let userId = LMUserManager.shared.currentUser?.userId {
            fetchRequest.predicate = NSPredicate(format: "isMarkedDeleted == NO AND userId == %@", userId)
        }
        
        do {
            let photos = try context.fetch(fetchRequest)
            LMLogger.log("📸 Fetched \(photos.count) photos from storage")
            return photos
        } catch {
            LMLogger.log("❌ Failed to fetch photos: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetch photo by ID
    /// - Parameter id: Photo ID
    /// - Returns: PhotoEntity or nil
    func fetchPhoto(byId id: String) -> PhotoEntity? {
        let fetchRequest: NSFetchRequest<PhotoEntity> = PhotoEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND isMarkedDeleted == NO", id)
        fetchRequest.fetchLimit = 1
        
        do {
            let photos = try context.fetch(fetchRequest)
            return photos.first
        } catch {
            LMLogger.log("❌ Failed to fetch photo by ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Delete Photo
    
    /// Delete a photo (soft delete)
    /// - Parameter id: Photo ID
    /// - Returns: Success or failure
    @discardableResult
    func deletePhoto(byId id: String) -> Bool {
        guard let photo = fetchPhoto(byId: id) else {
            LMLogger.log("❌ Photo not found with ID: \(id)")
            return false
        }
        
        // Soft delete
        photo.isMarkedDeleted = true
        
        do {
            try context.save()
            LMLogger.log("✅ Photo marked as deleted: \(id)")
            return true
        } catch {
            LMLogger.log("❌ Failed to delete photo: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Permanently delete a photo and its files
    /// - Parameter id: Photo ID
    /// - Returns: Success or failure
    @discardableResult
    func permanentlyDeletePhoto(byId id: String) -> Bool {
        guard let photo = fetchPhoto(byId: id) else {
            LMLogger.log("❌ Photo not found with ID: \(id)")
            return false
        }
        
        // Delete image files
        if let imagePath = photo.imagePath {
            deleteFile(at: imagePath)
        }
        
        if let referencePath = photo.referenceImagePath {
            deleteFile(at: referencePath)
        }
        
        // Delete from Core Data
        context.delete(photo)
        
        do {
            try context.save()
            LMLogger.log("✅ Photo permanently deleted: \(id)")
            return true
        } catch {
            LMLogger.log("❌ Failed to permanently delete photo: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveImageToFile(image: UIImage, photoId: String, isReference: Bool) -> String? {
        let fileName = isReference ? "\(photoId)_ref.jpg" : "\(photoId).jpg"
        let filePath = photosDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            LMLogger.log("❌ Failed to convert image to JPEG data")
            return nil
        }
        
        do {
            try imageData.write(to: filePath)
            LMLogger.log("✅ Image saved to: \(filePath.path)")
            return filePath.path
        } catch {
            LMLogger.log("❌ Failed to save image to file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteFile(at path: String) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
                LMLogger.log("✅ File deleted: \(path)")
            } catch {
                LMLogger.log("❌ Failed to delete file: \(error.localizedDescription)")
            }
        }
    }
    
    func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Sync Status
    
    /// Mark photo as synced with server
    /// - Parameters:
    ///   - id: Photo ID
    ///   - serverId: Server-assigned ID
    @discardableResult
    func markPhotoAsSynced(id: String, serverId: String) -> Bool {
        guard let photo = fetchPhoto(byId: id) else {
            return false
        }
        
        photo.isSynced = true
        photo.serverId = serverId
        
        do {
            try context.save()
            LMLogger.log("✅ Photo marked as synced: \(id)")
            return true
        } catch {
            LMLogger.log("❌ Failed to mark photo as synced: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get unsynced photos
    /// - Returns: Array of PhotoEntity that need to be synced
    func fetchUnsyncedPhotos() -> [PhotoEntity] {
        let fetchRequest: NSFetchRequest<PhotoEntity> = PhotoEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO AND isMarkedDeleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "capturedDate", ascending: true)]
        
        do {
            let photos = try context.fetch(fetchRequest)
            LMLogger.log("📤 Found \(photos.count) unsynced photos")
            return photos
        } catch {
            LMLogger.log("❌ Failed to fetch unsynced photos: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Save Context
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                LMLogger.log("✅ Core Data context saved")
            } catch {
                LMLogger.log("❌ Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}
