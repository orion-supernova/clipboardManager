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
    
    var displayName: String {
        switch self {
        case .monthly: return "Pro Access (Monthly)"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "Pro Access to all features. Renews Monthly."
        }
    }
}

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var isSubscribed = false
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
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
    
    func requestProducts() async {
        do {
            print("Requesting products...")
            let productIdentifiers = SubscriptionTier.allCases.map { $0.rawValue }
            print("Product IDs to request: \(productIdentifiers)")
            
            let storeProducts = try await Product.products(for: productIdentifiers)
            print("Received \(storeProducts.count) products from the store")
            
            subscriptions = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
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
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
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
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
}
