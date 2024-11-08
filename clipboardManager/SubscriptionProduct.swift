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
    
    private let productIdentifiers = Set([
        "mahmutclipboard_099_1m_3d0",
        "com.walhallaa.clipboardManager.pro.weekly"
    ])
    
    #if DEBUG
    private let debugIsSubscribedKey = "debugIsSubscribed"
    private let debugSubscriptionTierKey = "debugSubscriptionTier"
    private let debugExpirationDateKey = "debugExpirationDate"
    
    private var isDebugSubscription: Bool {
        get { UserDefaults.standard.bool(forKey: debugIsSubscribedKey) }
        set { UserDefaults.standard.set(newValue, forKey: debugIsSubscribedKey) }
    }
    #endif
    
    private init() {
        #if DEBUG
        // Load debug status if exists
        if isDebugSubscription {
            self.isSubscribed = true
            if let tierString = UserDefaults.standard.string(forKey: debugSubscriptionTierKey) {
                self.currentTier = SubscriptionTier(rawValue: tierString)
            }
            self.subscriptionExpirationDate = UserDefaults.standard.object(forKey: debugExpirationDateKey) as? Date
        }
        #endif
        
        Task {
            await fetchProducts()
            await checkSubscriptionStatus()
            setupTransactionListener()
        }
    }
    
    func fetchProducts() async {
        isLoading = true
        do {
            subscriptions = try await Product.products(for: productIdentifiers)
            isLoading = false
        } catch {
            print("Failed to fetch products:", error)
            isLoading = false
        }
    }
    
    func purchase(_ product: Product) async throws {
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
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            print("Failed to restore purchases:", error)
        }
    }
    
    private func setupTransactionListener() {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
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
    
    private func checkSubscriptionStatus() async {
        #if DEBUG
        if isDebugSubscription {
            return
        }
        #endif
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if let expirationDate = transaction.expirationDate,
                   expirationDate > Date() {
                    await MainActor.run {
                        self.isSubscribed = true
                        self.currentTier = SubscriptionTier(rawValue: transaction.productID)
                        self.subscriptionExpirationDate = expirationDate
                    }
                    break
                }
            }
        }
    }
    
    #if DEBUG
    func setDebugSubscriptionStatus(isSubscribed: Bool, tier: SubscriptionTier?) {
        self.isSubscribed = isSubscribed
        self.currentTier = tier
        self.subscriptionExpirationDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        
        // Persist debug status
        self.isDebugSubscription = isSubscribed
        UserDefaults.standard.set(tier?.rawValue, forKey: debugSubscriptionTierKey)
        UserDefaults.standard.set(self.subscriptionExpirationDate, forKey: debugExpirationDateKey)
        
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    func cancelDebugSubscription() {
        self.isSubscribed = false
        self.currentTier = nil
        self.subscriptionExpirationDate = nil
        
        // Clear debug status
        self.isDebugSubscription = false
        UserDefaults.standard.removeObject(forKey: debugSubscriptionTierKey)
        UserDefaults.standard.removeObject(forKey: debugExpirationDateKey)
        
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    #endif
}

// Add notification name
extension NSNotification.Name {
    static let subscriptionStatusChanged = NSNotification.Name("subscriptionStatusChanged")
}
