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
    
    // Primary accent colors - Deep purple to blue
    static let accent = Color(hex: "7C3AED")      // Deep purple
    static let secondary = Color(hex: "818CF8")    // Indigo blue
    
    static let text = Color.white
    static let textSecondary = Color(hex: "9999A3")
    
    // Premium button gradients - Rich purple to blue transition
    static let buttonGradient1 = Color(hex: "8B5CF6")  // Bright purple
    static let buttonGradient2 = Color(hex: "7C3AED")  // Deep purple
    static let buttonGradient3 = Color(hex: "6366F1")  // Indigo
    
    // Price gradient colors - Ethereal purple
    static let priceGradient1 = Color(hex: "C4B5FD")  // Light purple
    static let priceGradient2 = Color(hex: "8B5CF6")  // Medium purple
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
                    Color(hex: "1A1A2E")  // Slightly purple-tinted dark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                // Subtle gradient overlay with purple accent
                RadialGradient(
                    colors: [
                        Color(hex: "7C3AED").opacity(0.15),  // Deep purple
                        Color(hex: "6366F1").opacity(0.1),   // Indigo
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
            .padding(40)
            
            // Success overlay
            if subscriptionManager.isSubscribed {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("You're a Pro user now!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(SubscriptionColors.text)
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
            }
        }
        .frame(width: 800, height: 600)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private var featuresSection: some View {
        FeatureCardsContainer(isAnimating: isAnimating)
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
                    // Bring window to front before starting restore process
                    if let window = NSApp.windows.first(where: { $0.title == "Subscription" }) {
                        window.orderFrontRegardless()
                    }
                    
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .buttonStyle(FooterButtonStyle())
#if DEBUG
                Menu {
                    
                    Button("Debug: Set Monthly") {
                        subscriptionManager.setDebugSubscriptionStatus(
                            isSubscribed: true,
                            tier: .monthly
                        )
                    }
                    
                    Button("Debug: Set Yearly") {
                        subscriptionManager.setDebugSubscriptionStatus(
                            isSubscribed: true,
                            tier: .yearly
                        )
                    }
                    
                    Button("Debug: Cancel Sub") {
                        subscriptionManager.cancelDebugSubscription()
                    }
                    
                } label: {
                    Text("Restore Purchases - DEBUG")
                }
                .buttonStyle(FooterButtonStyle())
#endif
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
    
    #if DEBUG
    private var debugControls: some View {
        ScrollView(.vertical, showsIndicators: true) {
            GroupBox(label: Text("Debug Controls").bold()) {
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Button("Set Monthly") {
                            subscriptionManager.setDebugSubscriptionStatus(
                                isSubscribed: true,
                                tier: .monthly
                            )
                        }
                        .buttonStyle(DebugButtonStyle())
                        
                        Button("Set Yearly") {
                            subscriptionManager.setDebugSubscriptionStatus(
                                isSubscribed: true,
                                tier: .yearly
                            )
                        }
                        .buttonStyle(DebugButtonStyle())
                        
                        Button("Cancel Sub") {
                            subscriptionManager.cancelDebugSubscription()
                        }
                        .buttonStyle(DebugButtonStyle(isDestructive: true))
                    }
                    
                    // Add more debug controls here if needed
                    Text("Debug Info:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Current Tier: \(subscriptionManager.currentTier?.displayName ?? "None")")
                        .font(.caption)
                    Text("Is Subscribed: \(subscriptionManager.isSubscribed ? "Yes" : "No")")
                        .font(.caption)
                    if let date = subscriptionManager.subscriptionExpirationDate {
                        Text("Expires: \(date, style: .date)")
                            .font(.caption)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 200)  // Limit the height
            .padding(.top, 20)
        }
    }

    struct DebugButtonStyle: ButtonStyle {
        var isDestructive: Bool = false
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(isDestructive ? .red : SubscriptionColors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isDestructive ? Color.red.opacity(0.3) : SubscriptionColors.accent.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .opacity(configuration.isPressed ? 0.8 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        }
    }
    #endif
}

struct FeatureCardsContainer: View {
    let isAnimating: Bool
    @Namespace private var animation
    @State private var hoveredFeature: PremiumFeature?
    
    var body: some View {
        HStack(spacing: 25) {
            ForEach(Array(PremiumFeature.allCases.enumerated()), id: \.element.title) { index, feature in
                FeatureCard(
                    feature: feature,
                    isVisible: isAnimating,
                    delay: Double(index) * 0.2,
                    namespace: animation,
                    isHovered: hoveredFeature == feature
                )
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredFeature = isHovered ? feature : nil
                    }
                }
            }
        }
    }
}

struct FeatureCard: View {
    let feature: PremiumFeature
    let isVisible: Bool
    let delay: Double
    let namespace: Namespace.ID
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with matched geometry effect
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
                        .matchedGeometryEffect(id: "circle\(feature.title)", in: namespace)
                        .shadow(
                            color: SubscriptionColors.accent.opacity(0.3),
                            radius: isHovered ? 8 : 0
                        )
                )
            
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
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(SubscriptionColors.cardBg)
                    .matchedGeometryEffect(id: "card\(feature.title)", in: namespace)
                
                AnimatedBorder(isHovered: isHovered)
            }
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: isVisible)
    }
}

// Add this new view for the animated border
struct AnimatedBorder: View {
    let isHovered: Bool
    
    @State private var trimStart: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Static colored border
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            SubscriptionColors.accent,
                            SubscriptionColors.secondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .opacity(isHovered ? 0.8 : 0.3)
            
            // Traveling highlight
            RoundedRectangle(cornerRadius: 20)
                .trim(from: trimStart, to: trimStart + 0.15) // Shorter, more elegant line
                .stroke(
                    LinearGradient(
                        colors: [
                            SubscriptionColors.accent.opacity(0),
                            SubscriptionColors.accent,
                            SubscriptionColors.secondary,
                            SubscriptionColors.secondary.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .opacity(isHovered ? 0.8 : 0)
                .blur(radius: 0.5) // Subtle blur for glow effect
        }
        .onChange(of: isHovered) { newValue in
            if newValue {
                withAnimation(
                    .linear(duration: 1.5) // Slightly faster animation
                    .repeatForever(autoreverses: false)
                ) {
                    trimStart = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    trimStart = 0
                }
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
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                SubscriptionColors.priceGradient1,
                                SubscriptionColors.priceGradient2
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("/month")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
            }
            
            PremiumButton("Subscribe", action: onPurchase)
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(SubscriptionColors.cardBg)
                
                // Use a slightly modified border for subscription cards
                AnimatedBorder(isHovered: isHovered)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
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
    @State private var isHovered = false
    
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
                        colors: [
                            SubscriptionColors.buttonGradient1,
                            SubscriptionColors.buttonGradient2,
                            SubscriptionColors.buttonGradient3
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: SubscriptionColors.buttonGradient2.opacity(0.5),
                    radius: isHovered ? 12 : 8,
                    y: isHovered ? 2 : 4
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hover in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hover
            }
        }
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









