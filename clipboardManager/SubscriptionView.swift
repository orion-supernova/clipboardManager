//
//  SubscriptionView.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import SwiftUI
import StoreKit

enum PremiumFeature: CaseIterable {
    case unlimited, search, keyboard
    
    var title: String {
        switch self {
        case .unlimited: return "Unlimited History"
        case .search: return "Smart Search"
        case .keyboard: return "Quick Access"
        }
    }
    
    var icon: String {
        switch self {
        case .unlimited: return "infinity.circle.fill"
        case .search: return "magnifyingglass.circle.fill"
        case .keyboard: return "command.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .unlimited: return "Never lose your copied items"
        case .search: return "Find anything instantly"
        case .keyboard: return "Access clipboard with shortcuts"
        }
    }
}

struct SubscriptionColors {
    static let background = Color(hex: "0A0A0F")
    static let cardBg = Color(hex: "141419")
    static let accent = Color(hex: "6C72FF")  // Electric indigo
    static let secondary = Color(hex: "FF6B6B") // Coral pink
    static let text = Color.white
    static let textSecondary = Color(hex: "9999A3")
    static let gradient1 = Color(hex: "4A00E0")
    static let gradient2 = Color(hex: "8E2DE2")
}

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Product?
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Sophisticated gradient background
            LinearGradient(
                colors: [
                    SubscriptionColors.background,
                    SubscriptionColors.background.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                // Subtle gradient overlay
                RadialGradient(
                    colors: [
                        SubscriptionColors.accent.opacity(0.1),
                        SubscriptionColors.secondary.opacity(0.05),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 600
                )
            )
            
            VStack(spacing: 30) {
                // Title Bar
                Text("Unlock Premium Features")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [SubscriptionColors.text, SubscriptionColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(y: isAnimating ? 0 : -30)
                    .opacity(isAnimating ? 1 : 0)
                
                if subscriptionManager.isSubscribed {
                    VStack(spacing: 20) {
                        Text("You're a Pro user!")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(SubscriptionColors.text)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(PremiumButtonStyle())
                    }
                } else {
                    // Features Grid
                    featuresSection
                        .offset(y: isAnimating ? 0 : 50)
                        .opacity(isAnimating ? 1 : 0)
                    
                    // Subscription Plans
                    if subscriptionManager.subscriptions.isEmpty {
                        loadingView
                    } else {
                        subscriptionPlans
                            .offset(y: isAnimating ? 0 : 50)
                            .opacity(isAnimating ? 1 : 0)
                    }
                    
                    Spacer()
                    
                    // Footer
                    footerSection
                        .offset(y: isAnimating ? 0 : 30)
                        .opacity(isAnimating ? 1 : 0)
                }
            }
            .padding(40)
        }
        .frame(width: 800, height: 600)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private var featuresSection: some View {
        HStack(spacing: 25) {
            ForEach(Array(PremiumFeature.allCases.enumerated()), id: \.element.title) { index, feature in
                FeatureCard(
                    feature: feature,
                    isVisible: isAnimating,
                    delay: Double(index) * 0.2
                )
            }
        }
    }
    
    private var subscriptionPlans: some View {
        VStack(spacing: 16) {
            ForEach(subscriptionManager.subscriptions, id: \.id) { product in
                SubscriptionPlanCard(
                    product: product,
                    isSelected: selectedPlan?.id == product.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPlan = product
                        }
                    },
                    onPurchase: {
                        Task {
                            try? await subscriptionManager.purchase(product)
                        }
                    }
                )
            }
        }
    }
    
    private var footerSection: some View {
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: 20) {
                Link("Privacy Policy", destination: URL(string: "https://walhallaa.com/mahmut-clipboard-privacy-terms")!)
                    .buttonStyle(FooterButtonStyle())
                
                Text("•")
                    .foregroundColor(SubscriptionColors.textSecondary)
                
                Link("Terms of Use", destination: URL(string: "https://walhallaa.com/mahmut-clipboard-privacy-terms")!)
                    .buttonStyle(FooterButtonStyle())
                
                Text("•")
                    .foregroundColor(SubscriptionColors.textSecondary)
                
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .buttonStyle(FooterButtonStyle())
            }
            Spacer()
        }
        .font(.system(size: 14, design: .rounded))
    }
    
    private var loadingView: some View {
        VStack(spacing: 15) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(SubscriptionColors.accent)
            
            Text("Loading Subscriptions...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(SubscriptionColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

struct FeatureCard: View {
    let feature: PremiumFeature
    let isVisible: Bool
    let delay: Double
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: feature.icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [SubscriptionColors.accent, SubscriptionColors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(SubscriptionColors.cardBg)
                        .shadow(color: SubscriptionColors.accent.opacity(0.3), radius: isHovered ? 8 : 0)
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
            
            VStack(spacing: 8) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(SubscriptionColors.text)
                
                Text(feature.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SubscriptionColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    SubscriptionColors.accent.opacity(isHovered ? 0.5 : 0.2),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: isVisible)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// Update the SubscriptionPlanCard with new styling
struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(product.displayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(SubscriptionColors.text)
                
                Text(product.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(SubscriptionColors.accent)
                
                Text("/month")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
            }
            
            PremiumButton("Subscribe", action: onPurchase)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SubscriptionColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    SubscriptionColors.accent.opacity(isHovered ? 0.5 : 0.2),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovered = hovering
            }
        }
    }
}

struct PremiumButton: View {
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [SubscriptionColors.accent, SubscriptionColors.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RestoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(SubscriptionColors.accent)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SubscriptionColors.accent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [SubscriptionColors.accent, SubscriptionColors.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(SubscriptionColors.accent)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SubscriptionColors.accent.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
