//
//  PurchaseManager.swift
//  clipboardManager
//
//  Created by muratcankoc on 22/07/2024.
//

import SwiftUI
import RevenueCat

class PurchaseManager: ObservableObject {
    @Published var hasActiveSubscription = false
    
    init() {
        checkSubscriptionStatus()
    }
    
    func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let error = error {
                print("Error fetching customer info: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                // Check if the user has an active subscription
                self.hasActiveSubscription = customerInfo?.entitlements.active["Basic"] != nil
            }
        }
    }
    
    func purchase() {
        // Implement RevenueCat purchase logic here
        Purchases.shared.getOfferings { (offerings, error) in
            if let package = offerings?.current?.availablePackages.first {
                Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
                    if let error = error {
                        print("Error making purchase: \(error.localizedDescription)")
                    } else if !userCancelled {
                        print("Purchase successful")
                        self.checkSubscriptionStatus()
                    }
                }
            }
        }
    }
    
    func restorePurchases() {
        Purchases.shared.restorePurchases { (customerInfo, error) in
            if let error = error {
                print("Error restoring purchases: \(error.localizedDescription)")
            } else {
                print("Purchases restored")
                self.checkSubscriptionStatus()
            }
        }
    }
}
