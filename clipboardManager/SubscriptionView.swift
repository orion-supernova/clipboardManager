//
//  SubscriptionView.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            header
            
            if subscriptionManager.subscriptions.isEmpty {
                ProgressView()
            } else {
                subscriptionOptions
            }
            
            features
            
            restoreButton
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("Upgrade to Pro")
                .font(.title)
                .bold()
            
            Text("Unlock all features")
                .foregroundColor(.secondary)
        }
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionManager.subscriptions, id: \.id) { product in
                SubscriptionOptionView(product: product)
                    .onTapGesture {
                        Task {
                            try? await subscriptionManager.purchase(product)
                        }
                    }
            }
        }
    }
    
    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pro Features:")
                .font(.headline)
            
            FeatureRow(icon: "infinity", text: "Unlimited clipboard items")
            FeatureRow(icon: "magnifyingglass", text: "Search through history")
            FeatureRow(icon: "keyboard", text: "Keyboard navigation")
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await subscriptionManager.restorePurchases()
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.blue)
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(product.displayPrice)
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
        }
    }
}
