//
//  SubscriptionProduct.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import Foundation
import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case monthly = "com.walhallaa.clipboardmanager.monthly"
    case yearly = "com.walhallaa.clipboardmanager.yearly"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly Pro"
        case .yearly: return "Yearly Pro"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "Unlimited clipboard items, Search feature"
        case .yearly: return "Unlimited clipboard items, Search feature (Save 20%)"
        }
    }
}


@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isSubscribed = false
    
    private let productIdentifiers = [
        "mahmutclipboard_099_1m_3d0",
        "com.walhallaa.clipboardManager.pro.weekly"
    ]
    
    private init() {
        Task {
            await fetchProducts()
            await checkSubscriptionStatus()
            setupTransactionListener()
        }
    }
    
    private func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                self.isSubscribed = true
                break
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
        } catch {
            print("Failed to restore purchases:", error)
        }
    }
    
    private func setupTransactionListener() {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }
}
