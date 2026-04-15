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
    
    private(set) var persistentStoreLoadError: Error?
    private(set) var isUsingInMemoryFallbackStore = false
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        if let diskContainer = makePersistentContainer(storeDescription: nil, logSuccessMessage: "✅ Core Data loaded successfully") {
            return diskContainer
        }
        
        let fallbackDescription = NSPersistentStoreDescription()
        fallbackDescription.type = NSInMemoryStoreType
        
        if let fallbackContainer = makePersistentContainer(
            storeDescription: fallbackDescription,
            logSuccessMessage: "⚠️ Core Data is using an in-memory fallback store"
        ) {
            isUsingInMemoryFallbackStore = true
            return fallbackContainer
        }
        
        LMLogger.log("❌ Core Data fallback store failed to load; continuing without a persistent store")
        return NSPersistentContainer(name: "processor")
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private func makePersistentContainer(storeDescription: NSPersistentStoreDescription?,
                                         logSuccessMessage: String) -> NSPersistentContainer? {
        let container = NSPersistentContainer(name: "processor")
        
        if let storeDescription {
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.persistentStoreDescriptions.forEach { description in
            description.shouldAddStoreAsynchronously = false
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let loadError {
            persistentStoreLoadError = persistentStoreLoadError ?? loadError
            LMLogger.log("❌ Core Data failed to load: \(loadError.localizedDescription)")
            return nil
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        LMLogger.log(logSuccessMessage)
        return container
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
    
    /// Save a photo to local storage (with Live Photo support)
    /// - Parameters:
    ///   - photoData: The captured photo data (including Live Photo info)
    ///   - referenceImage: Optional reference composition image
    ///   - title: Optional title
    /// - Returns: The saved PhotoEntity or nil if failed
    @discardableResult
    func savePhoto(photoData: CapturedPhotoData, referenceImage: UIImage? = nil, title: String? = nil) -> PhotoEntity? {
        let photoId = UUID().uuidString
        let timestamp = Date()
        
        // Save main image to file (with metadata for Live Photo)
        let imagePath: String?
        if photoData.isLivePhoto, let imageData = photoData.imageData {
            // For Live Photo, use original data to preserve metadata
            imagePath = saveImageDataToFile(imageData: imageData, photoId: photoId, isReference: false)
            LMLogger.log("✅ Saved Live Photo image with metadata")
        } else {
            // For regular photo, use JPEG compression
            imagePath = saveImageToFile(image: photoData.image, photoId: photoId, isReference: false)
        }
        
        guard imagePath != nil else {
            LMLogger.log("❌ Failed to save main image to file")
            return nil
        }
        
        // Save Live Photo video if available
        var livePhotoVideoPath: String?
        if photoData.isLivePhoto, let videoURL = photoData.livePhotoVideoURL {
            livePhotoVideoPath = saveLivePhotoVideo(from: videoURL, photoId: photoId)
            if livePhotoVideoPath != nil {
                LMLogger.log("✅ Live Photo video saved")
            }
        }
        
        // Save reference image if provided
        var referenceImagePath: String?
        if let refImage = referenceImage {
            referenceImagePath = saveImageToFile(image: refImage, photoId: photoId, isReference: true)
        }
        
        // Generate thumbnail
        let thumbnail = photoData.image
        let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7)
        
        // Create Core Data entity
        let photoEntity = PhotoEntity(context: context)
        photoEntity.id = photoId
        photoEntity.userId = LMUserManager.userModel?.userId
        photoEntity.title = title
        photoEntity.imagePath = imagePath
        photoEntity.referenceImagePath = referenceImagePath
        photoEntity.thumbnailData = thumbnailData
        photoEntity.capturedDate = timestamp
        photoEntity.isSynced = false
        photoEntity.isMarkedDeleted = false
        photoEntity.isLivePhoto = photoData.isLivePhoto
        photoEntity.livePhotoVideoPath = livePhotoVideoPath
        
        // Save context
        do {
            try context.save()
            LMLogger.log("✅ Photo saved successfully with ID: \(photoId), isLivePhoto: \(photoData.isLivePhoto)")
            return photoEntity
        } catch {
            LMLogger.log("❌ Failed to save photo to Core Data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save a photo to local storage (backward compatibility)
    /// - Parameters:
    ///   - image: The captured photo
    ///   - referenceImage: Optional reference composition image
    ///   - title: Optional title
    /// - Returns: The saved PhotoEntity or nil if failed
    @discardableResult
    func savePhoto(image: UIImage, referenceImage: UIImage? = nil, title: String? = nil) -> PhotoEntity? {
        let photoData = CapturedPhotoData(image: image)
        return savePhoto(photoData: photoData, referenceImage: referenceImage, title: title)
    }
    
    /// Save Live Photo video file
    /// - Parameters:
    ///   - sourceURL: Source video URL (temporary location)
    ///   - photoId: Photo ID
    /// - Returns: Saved video file path or nil if failed
    private func saveLivePhotoVideo(from sourceURL: URL, photoId: String) -> String? {
        let fileName = "\(photoId)_live.mov"
        let destinationURL = photosDirectory.appendingPathComponent(fileName)
        
        do {
            // 复制视频文件到 Photos 目录
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            LMLogger.log("✅ Live Photo video saved to: \(destinationURL.path)")
            return destinationURL.path
        } catch {
            LMLogger.log("❌ Failed to save Live Photo video: \(error.localizedDescription)")
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
        if let userId = LMUserManager.userModel?.userId {
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
        
        // Delete Live Photo video file
        if let videoPath = photo.livePhotoVideoPath {
            deleteFile(at: videoPath)
            LMLogger.log("🗑️ Live Photo video file deleted")
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
    
    /// Save image data to file (preserves metadata)
    /// - Parameters:
    ///   - imageData: Raw image data with metadata
    ///   - photoId: Photo ID
    ///   - isReference: Whether this is a reference image
    /// - Returns: File path or nil if failed
    private func saveImageDataToFile(imageData: Data, photoId: String, isReference: Bool) -> String? {
        let fileName = isReference ? "\(photoId)_ref.jpg" : "\(photoId).jpg"
        let filePath = photosDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: filePath)
            LMLogger.log("✅ Image data saved to: \(filePath.path)")
            return filePath.path
        } catch {
            LMLogger.log("❌ Failed to save image data to file: \(error.localizedDescription)")
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
