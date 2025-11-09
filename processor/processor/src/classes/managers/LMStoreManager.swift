//
//  LMStoreManager.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import Foundation
import StoreKit




// MARK: - Store Error Types
enum StoreError: LocalizedError {
    case productNotFound
    case purchaseFailed(underlying: Error)
    case purchaseCancelled
    case verificationFailed
    case networkError
    case serverError(message: String)
    case invalidReceipt
    case restorationFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "The subscription plan is not available at this time."
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .verificationFailed:
            return "Unable to verify your purchase. Please try again."
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .serverError(let message):
            return message
        case .invalidReceipt:
            return "Invalid purchase receipt. Please contact support."
        case .restorationFailed:
            return "Unable to restore purchases. Please try again."
        }
    }
}

// MARK: - Subscription Verification Models
struct SubscriptionVerificationRequest: Codable {
    let transactionId: String
    let productId: String
    let purchaseDate: String
    let receiptData: String
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case productId = "product_id"
        case purchaseDate = "purchase_date"
        case receiptData = "receipt_data"
        case userId = "user_id"
    }
}

struct SubscriptionVerificationResponse: Codable {
    let success: Bool
    let subscriptionType: String
    let expirationDate: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case subscriptionType = "subscription_type"
        case expirationDate = "expiration_date"
    }
}

// MARK: - Store Manager
class LMStoreManager {
    
    // MARK: - Singleton
    static let shared = LMStoreManager()
    
    // MARK: - Product Identifiers
    enum ProductIdentifier: String, CaseIterable {
        case plusMonthly = "com.processor.plus.monthly"
        case lifelong = "com.processor.lifelong"
    }
    
    // MARK: - Subscription Status
    enum SubscriptionStatus: String {
        case free
        case plus
        case lifelong
    }
    
    // MARK: - Properties
    private var products: [Product] = []
    private var purchasedProductIDs: Set<String> = []
    private var transactionListener: Task<Void, Error>?
    private(set) var currentSubscriptionStatus: SubscriptionStatus = .free
    
    // MARK: - Storage Keys
    private enum StorageKeys {
        static let purchasedProductIDs = "com.processor.purchasedProductIDs"
        static let subscriptionStatus = "com.processor.subscriptionStatus"
        static let lastVerificationDate = "com.processor.lastVerificationDate"
    }
    
    // MARK: - Initialization
    private init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the store manager and start listening for transactions
    func initialize() async {
        await loadProducts()
        listenForTransactions()
        await restorePurchases()
    }
    
    /// Load products from App Store
    func loadProducts() async {
        do {
            let productIdentifiers = ProductIdentifier.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIdentifiers)
            self.products = storeProducts
            LMLogger.log("✅ Loaded \(storeProducts.count) products from App Store")
        } catch {
            LMLogger.log("❌ Failed to load products: \(error.localizedDescription)")
            // Retry after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await loadProducts()
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction {
        LMLogger.log("🛒 Starting purchase for: \(product.id)")
        
        // Initiate purchase
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)
            
            // Handle the transaction
            await handle(transaction: transaction)
            
            LMLogger.log("✅ Purchase successful: \(transaction.id)")
            return transaction
            
        case .userCancelled:
            LMLogger.log("⚠️ Purchase cancelled by user")
            throw StoreError.purchaseCancelled
            
        case .pending:
            LMLogger.log("⏳ Purchase pending")
            throw StoreError.purchaseFailed(underlying: NSError(domain: "StoreKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Purchase is pending approval"]))
            
        @unknown default:
            LMLogger.log("❌ Unknown purchase result")
            throw StoreError.purchaseFailed(underlying: NSError(domain: "StoreKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"]))
        }
    }
    
    /// Restore purchases
    func restorePurchases() async {
        LMLogger.log("🔄 Restoring purchases...")
        
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Check current entitlements
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                await handle(transaction: transaction)
            }
            
            await updateSubscriptionStatus()
            LMLogger.log("✅ Purchases restored successfully")
        } catch {
            LMLogger.log("❌ Failed to restore purchases: \(error.localizedDescription)")
        }
    }
    
    /// Check current subscription status
    func checkSubscriptionStatus() async -> SubscriptionStatus {
        // Check for lifelong purchase first
        if purchasedProductIDs.contains(ProductIdentifier.lifelong.rawValue) {
            return .lifelong
        }
        
        // Check for active Plus subscription
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == ProductIdentifier.plusMonthly.rawValue {
                return .plus
            }
        }
        
        return .free
    }
    
    /// Get product by identifier
    func getProduct(for identifier: ProductIdentifier) -> Product? {
        return products.first { $0.id == identifier.rawValue }
    }
    
    // MARK: - Private Methods
    
    /// Listen for transaction updates
    private func listenForTransactions() {
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.handle(transaction: transaction)
                    await self.updateSubscriptionStatus()
                } catch {
                    LMLogger.log("❌ Transaction update error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handle a transaction
    private func handle(transaction: Transaction) async {
        LMLogger.log("📦 Handling transaction: \(transaction.id)")
        
        // Add to purchased products
        purchasedProductIDs.insert(transaction.productID)
        saveCachedData()
        
        // Verify with server
        do {
            try await verifyPurchaseWithServer(transaction: transaction)
        } catch {
            LMLogger.log("⚠️ Server verification failed, will retry: \(error.localizedDescription)")
            // Queue for retry (simplified - in production, implement proper retry queue)
        }
        
        // Finish the transaction
        await transaction.finish()
    }
    
    /// Verify purchase with backend server
    private func verifyPurchaseWithServer(transaction: Transaction) async throws {
        LMLogger.log("🔐 Verifying purchase with server...")
        
        // Prepare request data
        let dateFormatter = ISO8601DateFormatter()
        let purchaseDate = dateFormatter.string(from: transaction.purchaseDate)
        
        // Get receipt data (simplified - in production, get actual receipt)
        let receiptData = String(transaction.id)
        
        let request = SubscriptionVerificationRequest(
            transactionId: String(transaction.id),
            productId: transaction.productID,
            purchaseDate: purchaseDate,
            receiptData: receiptData,
            userId: LMUserManager.shared.currentUser?.userId
        )
        
        // Convert to dictionary for API call
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let jsonData = try encoder.encode(request)
        let params = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
        
        // Make API call
        return try await withCheckedThrowingContinuation { continuation in
            LMApiClient.request(
                "/subscriptions/verify",
                method: .post,
                params: params,
                type: SubscriptionVerificationResponse.self
            ) { response in
                if response.requestSuccess, let data = response.value {
                    if data.success {
                        LMLogger.log("✅ Server verification successful")
                        // Update user subscription status
                        self.updateUserSubscription(
                            type: data.subscriptionType,
                            expirationDate: data.expirationDate
                        )
                        continuation.resume()
                    } else {
                        LMLogger.log("❌ Server verification failed")
                        continuation.resume(throwing: StoreError.verificationFailed)
                    }
                } else {
                    let errorMessage = response.message ?? "Unknown error"
                    LMLogger.log("❌ Server error: \(errorMessage)")
                    continuation.resume(throwing: StoreError.serverError(message: errorMessage))
                }
            }
        }
    }
    
    /// Update subscription status
    private func updateSubscriptionStatus() async {
        let status = await checkSubscriptionStatus()
        currentSubscriptionStatus = status
        
        // Save to UserDefaults
        UserDefaults.standard.set(status.rawValue, forKey: StorageKeys.subscriptionStatus)
        
        // Post notification for UI updates
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionStatusDidChange, object: status)
        }
        
        LMLogger.log("📊 Subscription status updated: \(status.rawValue)")
    }
    
    /// Update user subscription in user model
    private func updateUserSubscription(type: String, expirationDate: String?) {
        LMLogger.log("📝 Updating user subscription: \(type)")
        
        // Update current user info with new subscription
        if var currentUser = LMUserManager.shared.currentUser {
            // Create updated user info with new subscription
            let updatedUser = LMUserInfo(
                userId: currentUser.userId,
                username: currentUser.username,
                email: currentUser.email,
                subscription: type
            )
            LMUserManager.shared.updateUserInfo(updatedUser)
            LMLogger.log("✅ User subscription updated in local storage")
        }
    }
    
    /// Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    /// Load cached data
    private func loadCachedData() {
        if let savedIDs = UserDefaults.standard.array(forKey: StorageKeys.purchasedProductIDs) as? [String] {
            purchasedProductIDs = Set(savedIDs)
        }
        
        if let savedStatus = UserDefaults.standard.string(forKey: StorageKeys.subscriptionStatus),
           let status = SubscriptionStatus(rawValue: savedStatus) {
            currentSubscriptionStatus = status
        }
    }
    
    /// Save cached data
    private func saveCachedData() {
        UserDefaults.standard.set(Array(purchasedProductIDs), forKey: StorageKeys.purchasedProductIDs)
        UserDefaults.standard.set(currentSubscriptionStatus.rawValue, forKey: StorageKeys.subscriptionStatus)
    }
    
    deinit {
        transactionListener?.cancel()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let subscriptionStatusDidChange = Notification.Name("subscriptionStatusDidChange")
}

// MARK: - SubscriptionPlanType Extension
extension SubscriptionPlanType {
    var productIdentifier: LMStoreManager.ProductIdentifier? {
        switch self {
        case .free:
            return nil
        case .plus:
            return .plusMonthly
        case .lifelong:
            return .lifelong
        }
    }
}
