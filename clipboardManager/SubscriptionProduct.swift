//
//  SubscriptionProduct.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import Foundation
import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case monthly = "mahmutclipboard_099_1m_3d0"
    case weekly = "com.walhallaa.clipboardManager.pro.weekly"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly Pro"
        case .weekly: return "Weekly Pro"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "Unlimited clipboard items, Search feature"
        case .weekly: return "Unlimited clipboard items, Search feature"
        }
    }
}

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isSubscribed = false
    @Published private(set) var currentTier: SubscriptionTier?
    @Published private(set) var subscriptionExpirationDate: Date?
    
    // Update product identifiers to match your StoreKit configuration
    private let productIdentifiers = Set([
        "mahmutclipboard_099_1m_3d0",  // Monthly subscription ID
        "com.walhallaa.clipboardManager.pro.weekly"  // Weekly subscription ID
    ])
    
    // Cache keys
    private let lastVerifiedKey = "lastVerifiedDate"
    private let cachedSubscriptionStatusKey = "cachedSubscriptionStatus"
    private let cachedSubscriptionTierKey = "cachedSubscriptionTier"
    private let cachedExpirationDateKey = "cachedExpirationDate"
    
    // Verification interval (e.g., verify once per day)
    private let verificationInterval: TimeInterval = 24 * 60 * 60
    
    private init() {
        // Load cached values first
        loadCachedSubscriptionStatus()
        
        // Only check online if needed
        Task {
            await fetchProducts()
            if shouldVerifySubscription() {
                await checkSubscriptionStatus()
            }
            setupTransactionListener()
        }
    }
    
    private func loadCachedSubscriptionStatus() {
        let defaults = UserDefaults.standard
        isSubscribed = defaults.bool(forKey: cachedSubscriptionStatusKey)
        if let tierString = defaults.string(forKey: cachedSubscriptionTierKey) {
            currentTier = SubscriptionTier(rawValue: tierString)
        }
        subscriptionExpirationDate = defaults.object(forKey: cachedExpirationDateKey) as? Date
    }
    
    private func cacheSubscriptionStatus() {
        let defaults = UserDefaults.standard
        defaults.set(isSubscribed, forKey: cachedSubscriptionStatusKey)
        defaults.set(currentTier?.rawValue, forKey: cachedSubscriptionTierKey)
        defaults.set(subscriptionExpirationDate, forKey: cachedExpirationDateKey)
        defaults.set(Date(), forKey: lastVerifiedKey)
    }
    
    private func shouldVerifySubscription() -> Bool {
        let defaults = UserDefaults.standard
        guard let lastVerified = defaults.object(forKey: lastVerifiedKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastVerified) >= verificationInterval
    }
    
    private func checkSubscriptionStatus() async {
        do {
            var hasActiveSubscription = false
            
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        await MainActor.run {
                            self.isSubscribed = true
                            self.currentTier = SubscriptionTier(rawValue: transaction.productID)
                            self.subscriptionExpirationDate = expirationDate
                        }
                        hasActiveSubscription = true
                        break
                    }
                }
            }
            
            // Cache the verified status
            cacheSubscriptionStatus()
            
        } catch {
            print("Failed to verify subscription status:", error)
            // On error, fall back to cached values
        }
    }
    
    private func setupTransactionListener() {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        // Only update if the subscription is not expired
                        if let expirationDate = transaction.expirationDate,
                           expirationDate > Date() {
                            self.isSubscribed = true
                            self.currentTier = SubscriptionTier(rawValue: transaction.productID)
                            self.subscriptionExpirationDate = expirationDate
                        } else {
                            self.isSubscribed = false
                            self.currentTier = nil
                            self.subscriptionExpirationDate = nil
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }
    
    func fetchProducts() async {
        do {
            isLoading = true
            let products = try await Product.products(for: productIdentifiers)
            await MainActor.run {
                self.subscriptions = products.sorted { $0.price < $1.price }
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch products:", error)
            isLoading = false
        }
    }
    
    func purchase(_ product: Product) async throws {
        // Store current window and its level
        let subscriptionWindow = NSApp.windows.first(where: { $0.title == "Subscription" })
        let originalLevel = subscriptionWindow?.level
        
        // Lower window level temporarily
        DispatchQueue.main.async {
            subscriptionWindow?.level = .normal
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                case .unverified:
                    print("Unverified transaction")
                }
            case .userCancelled:
                print("User cancelled")
            case .pending:
                print("Transaction pending")
            @unknown default:
                print("Unknown purchase result")
            }
            
            // Restore window level after purchase attempt
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .makeAppVisibleNotification, object: nil)
                subscriptionWindow?.level = .screenSaver
            }
        } catch {
            print("Purchase failed:", error)
            
            // Restore window level even if purchase fails
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .makeAppVisibleNotification, object: nil)
                subscriptionWindow?.level = .screenSaver
            }
        }
    }
    
    func restorePurchases() async {
        // Store current window and its level
        let subscriptionWindow = NSApp.windows.first(where: { $0.title == "Subscription" })
        let originalLevel = subscriptionWindow?.level
        
        // Lower window level temporarily
        DispatchQueue.main.async {
            subscriptionWindow?.level = .normal
        }
        
        do {
            try await AppStore.sync()
            
            // Wait briefly then restore window level
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            DispatchQueue.main.async {
                subscriptionWindow?.level = originalLevel ?? .modalPanel
                subscriptionWindow?.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        } catch {
            print("Failed to restore purchases:", error)
            
            // Restore window level even if restore fails
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .makeAppVisibleNotification, object: nil)
                subscriptionWindow?.level = .screenSaver
            }
        }
    }
    private func reOrderWindowsAfterFail() {
        
    }
    
    #if DEBUG
    // Debug functions should still work the same way for testing
    func setDebugSubscriptionStatus(isSubscribed: Bool, tier: SubscriptionTier?) {
        self.isSubscribed = isSubscribed
        self.currentTier = tier
        self.subscriptionExpirationDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    func cancelDebugSubscription() {
        self.isSubscribed = false
        self.currentTier = nil
        self.subscriptionExpirationDate = nil
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    #endif
}

// Add notification name
extension NSNotification.Name {
    static let subscriptionStatusChanged = NSNotification.Name("subscriptionStatusChanged")
}
