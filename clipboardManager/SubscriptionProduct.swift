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
        case .monthly: return "Pro Access (Monthly)"
        case .weekly: return "Pro Access (Weekly)"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "Pro Access to all features. Renews Monthly."
        case .weekly: return "Pro Access to all features. Renews Weekly."
        }
    }
}

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoading = true
    @Published var isPresentingSubscription = false
    
    private var updateListenerTask: Task<Void, Error>?
    
    private let productIdentifiers = [
        "mahmutclipboard_099_1m_3d0",
        "com.walhallaa.clipboardManager.pro.weekly"
    ]
    
    private init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await fetchProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }
        
        await updateSubscriptionStatus()
        await transaction.finish()
    }
    
    func fetchProducts() async {
        do {
            isLoading = true
            print("Requesting products...")
            let storeProducts = try await Product.products(for: productIdentifiers)
            print("Received \(storeProducts.count) products from the store")
            
            await MainActor.run {
                self.subscriptions = storeProducts.sorted { $0.price < $1.price }
                self.isLoading = false
            }
        } catch {
            print("Failed to fetch products: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return
            }
            await transaction.finish()
            await updateSubscriptionStatus()
            await fetchProducts() // Refresh products after purchase
        case .userCancelled:
            print("User cancelled")
        case .pending:
            print("Transaction pending")
        @unknown default:
            print("Unknown purchase result")
        }
    }
    
    func updateSubscriptionStatus() async {
        var isSubscribedTemp = false
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.productType == .autoRenewable {
                let isExpired = transaction.expirationDate != nil &&
                    transaction.expirationDate! < Date() ||
                    transaction.revocationDate != nil
                
                if !isExpired {
                    isSubscribedTemp = true
                    break
                }
            }
        }
        
        await MainActor.run {
            self.isSubscribed = isSubscribedTemp
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            await fetchProducts() // Refresh products after restore
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
}
