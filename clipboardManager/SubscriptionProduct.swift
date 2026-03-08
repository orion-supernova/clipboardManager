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
        "com.walhallaa.clipboardManager.pro.weekly",
        "mahmutclipboard_099_1m_3d0"
    ])
    
    private let debugIsSubscribedKey = "debugIsSubscribed"
    private let debugSubscriptionTierKey = "debugSubscriptionTier"
    private let debugExpirationDateKey = "debugExpirationDate"
    
    private var isDebugSubscription: Bool {
        get { UserDefaults.standard.bool(forKey: debugIsSubscribedKey) }
        set { UserDefaults.standard.set(newValue, forKey: debugIsSubscribedKey) }
    }
    
    private init() {
        // Load debug status if exists
        if isDebugSubscription {
            self.isSubscribed = true
            if let tierString = UserDefaults.standard.string(forKey: debugSubscriptionTierKey) {
                self.currentTier = SubscriptionTier(rawValue: tierString)
            }
            self.subscriptionExpirationDate = UserDefaults.standard.object(forKey: debugExpirationDateKey) as? Date
        }
        
        Task {
            await fetchProducts()
            await checkSubscriptionStatus()
            setupTransactionListener()
        }
    }
    
    func fetchProducts() async {
        isLoading = true
        do {
            subscriptions = try await Product.products(for: productIdentifiers).sorted(by: { $0.price < $1.price })
            isLoading = false
        } catch {
            print("Failed to fetch products:", error)
            isLoading = false
        }
    }
    
    private func manageSubscriptionWindow(operation: @escaping () async throws -> Void) async {
        // Store current window and its level
        let subscriptionWindow = NSApp.windows.first(where: { $0.title == "Subscription" })
        let originalLevel = subscriptionWindow?.level
        
        // Lower window level temporarily
        DispatchQueue.main.async {
            subscriptionWindow?.level = .normal
        }
        
        do {
            try await operation()
            
            // Restore window level and ensure visibility
            DispatchQueue.main.async {
                subscriptionWindow?.level = originalLevel ?? .screenSaver
                NotificationCenter.default.post(name: .makeAppVisibleNotification, object: nil )
                NSApp.activate(ignoringOtherApps: true)
                subscriptionWindow?.makeKeyAndOrderFront(nil)
                subscriptionWindow?.orderFrontRegardless()
            }
        } catch {
            print("Operation failed:", error)
            
            // Restore window level even on error
            DispatchQueue.main.async {
                subscriptionWindow?.level = originalLevel ?? .screenSaver
                NotificationCenter.default.post(name: .makeAppVisibleNotification, object: nil )
                NSApp.activate(ignoringOtherApps: true)
                subscriptionWindow?.makeKeyAndOrderFront(nil)
                subscriptionWindow?.orderFrontRegardless()
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        await manageSubscriptionWindow {
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
    }
    
    func restorePurchases() async {
        await manageSubscriptionWindow { [weak self] in
            guard let self else { return }
            try await AppStore.sync()
            await checkSubscriptionStatus()
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
    
    func setSubscriptionWithCouponCode () {
        self.isSubscribed = true
        self.currentTier = .weekly
        self.subscriptionExpirationDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        
        // Persist debug status
        self.isDebugSubscription = true
        UserDefaults.standard.set(SubscriptionTier.weekly.rawValue, forKey: debugSubscriptionTierKey)
        UserDefaults.standard.set(self.subscriptionExpirationDate, forKey: debugExpirationDateKey)
        
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    func cancelSubscriptionWithCouponCode() {
        self.isSubscribed = false
        self.currentTier = nil
        self.subscriptionExpirationDate = nil
        
        // Clear debug status
        self.isDebugSubscription = false
        UserDefaults.standard.removeObject(forKey: debugSubscriptionTierKey)
        UserDefaults.standard.removeObject(forKey: debugExpirationDateKey)
        
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
}

// Add notification name
extension NSNotification.Name {
    static let subscriptionStatusChanged = NSNotification.Name("subscriptionStatusChanged")
}
