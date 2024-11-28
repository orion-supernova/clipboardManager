//
//  SubscriptionView.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import SwiftUI
import StoreKit

enum AppFeature: Identifiable {
    case clipboardStorage, clipboardAccess, smartDetection, pasteAnywhere, smartSearch
    
    var id: String { title }
    
    var title: String {
        switch self {
        case .clipboardStorage: return "Clipboard Storage"
        case .clipboardAccess: return "Clipboard History Access"
        case .smartDetection: return "Smart Content Detection"
        case .pasteAnywhere: return "Paste Anywhere"
        case .smartSearch: return "Smart Search"
        }
    }
    
    var icon: String {
        switch self {
        case .clipboardStorage: return "square.and.arrow.down.fill"
        case .clipboardAccess: return "list.clipboard.fill"
        case .smartDetection: return "wand.and.stars"
        case .pasteAnywhere: return "command.circle.fill"
        case .smartSearch: return "magnifyingglass.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .clipboardStorage: return "Store unlimited clipboard items"
        case .clipboardAccess: return "Access your clipboard history"
        case .smartDetection: return "Auto-detect colors, images, files & more"
        case .pasteAnywhere: return "Paste text in any application"
        case .smartSearch: return "Find anything instantly in your history"
        }
    }
    
    var freeAccess: String {
        switch self {
        case .clipboardAccess: return "3 items"
        case .clipboardStorage, .pasteAnywhere, .smartDetection: return "✓"
        case .smartSearch: return "—"
        }
    }
    
    var proAccess: String {
        switch self {
        case .clipboardAccess: return "Unlimited"
        default: return "✓"
        }
    }
    
    var isPremium: Bool {
        switch self {
        case .clipboardStorage, .pasteAnywhere, .smartDetection: return false
        case .clipboardAccess, .smartSearch: return true
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
                Text("Upgrade to Pro Access")
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
                
                // Feature Comparison
                FeatureComparisonView()
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
//        .frame(width: 800, height: 800)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
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
                    
                    Button("Debug: Set Weekly") {
                        subscriptionManager.setDebugSubscriptionStatus(
                            isSubscribed: true,
                            tier: .weekly
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
    
//    #if DEBUG
//    private var debugControls: some View {
//        ScrollView(.vertical, showsIndicators: true) {
//            GroupBox(label: Text("Debug Controls").bold()) {
//                VStack(spacing: 16) {
//                    HStack(spacing: 20) {
//                        Button("Set Monthly") {
//                            subscriptionManager.setDebugSubscriptionStatus(
//                                isSubscribed: true,
//                                tier: .monthly
//                            )
//                        }
//                        .buttonStyle(DebugButtonStyle())
//                                                
//                        Button("Cancel Sub") {
//                            subscriptionManager.cancelDebugSubscription()
//                        }
//                        .buttonStyle(DebugButtonStyle(isDestructive: true))
//                    }
//                    
//                    // Add more debug controls here if needed
//                    Text("Debug Info:")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    Text("Current Tier: \(subscriptionManager.currentTier?.displayName ?? "None")")
//                        .font(.caption)
//                    Text("Is Subscribed: \(subscriptionManager.isSubscribed ? "Yes" : "No")")
//                        .font(.caption)
//                    if let date = subscriptionManager.subscriptionExpirationDate {
//                        Text("Expires: \(date, style: .date)")
//                            .font(.caption)
//                    }
//                }
//                .padding(8)
//            }
//            .frame(maxHeight: 200)  // Limit the height
//            .padding(.top, 20)
//        }
//    }
//
//    struct DebugButtonStyle: ButtonStyle {
//        var isDestructive: Bool = false
//        
//        func makeBody(configuration: Configuration) -> some View {
//            configuration.label
//                .font(.system(size: 13, weight: .medium, design: .rounded))
//                .foregroundColor(isDestructive ? .red : SubscriptionColors.accent)
//                .padding(.horizontal, 12)
//                .padding(.vertical, 6)
//                .background(
//                    RoundedRectangle(cornerRadius: 6)
//                        .stroke(
//                            isDestructive ? Color.red.opacity(0.3) : SubscriptionColors.accent.opacity(0.3),
//                            lineWidth: 1
//                        )
//                )
//                .opacity(configuration.isPressed ? 0.8 : 1.0)
//                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
//        }
//    }
//    #endif
}

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
                .trim(from: trimStart, to: trimStart + 0.15)
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
                .blur(radius: 0.5)
        }
        .onChange(of: isHovered) { newValue in
            if newValue {
                withAnimation(
                    .linear(duration: 1.5)
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

struct FeatureComparisonView: View {
    let features = [
        AppFeature.clipboardStorage,
        AppFeature.clipboardAccess,
        AppFeature.smartDetection,
        AppFeature.pasteAnywhere,
        AppFeature.smartSearch
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 0) {
                Text("Feature")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 300, alignment: .leading)
                Text("Free")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 100)
                Text("Pro")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 100)
            }
            .foregroundColor(SubscriptionColors.textSecondary)
            
            Divider()
                .padding(.vertical, 8)
            
            // Feature rows
            ForEach(features) { feature in
                HStack(spacing: 0) {
                    // Feature description
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [SubscriptionColors.accent, SubscriptionColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .foregroundColor(SubscriptionColors.text)
                            Text(feature.description)
                                .font(.system(size: 12))
                                .foregroundColor(SubscriptionColors.textSecondary)
                        }
                    }
                    .frame(width: 300, alignment: .leading)
                    
                    // Free tier access
                    Text(feature.freeAccess)
                        .foregroundColor(feature.freeAccess == "✓" ? .green : SubscriptionColors.textSecondary)
                        .frame(width: 100)
                    
                    // Pro tier access
                    Text(feature.proAccess)
                        .foregroundColor(feature.proAccess == "✓" ? .green : SubscriptionColors.textSecondary)
                        .frame(width: 100)
                }
            }
        }
        .padding(24)
        .background(SubscriptionColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - PLAN CARD
struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 24) {
            // Left side - Title and Description
            VStack(alignment: .leading, spacing: 8) {
                Text(product.displayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(SubscriptionColors.text)
                    .lineLimit(1)
                
                Text(getSubscriptionDescription())
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true) // Allows text to wrap properly
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 70)
            
            // Right side - Price and Button
            HStack(spacing: 20) {
                // Price section
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
                    
                    if product.subscription?.subscriptionPeriod.unit == .month {
                        Text("3 day free trial")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(SubscriptionColors.textSecondary)
                        Text("Then \(product.displayPrice)/month")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(SubscriptionColors.textSecondary)
                    } else {
                        Text("\(getMonthlyPrice())/month")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(SubscriptionColors.textSecondary)
                    }
                }
                .frame(width: 120)
                
                // Subscribe button with flexible width
                PremiumButton(
                    product.subscription?.introductoryOffer != nil ? "Try Free" : "Subscribe",
                    action: onPurchase
                )
                .frame(minWidth: 100, maxWidth: 130)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(SubscriptionColors.cardBg)
                
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
    
    private func getMonthlyPrice() -> String {
        guard let subscription = product.subscription else { return "" }
        
        let price = product.price
        let unit = subscription.subscriptionPeriod.unit
        let unitCount = subscription.subscriptionPeriod.value
        
        // Convert to monthly price if needed
        let monthlyPrice: Decimal
        switch unit {
        case .month:
            monthlyPrice = price
            print("Unit Count Month", unitCount)
        case .year:
            monthlyPrice = price / Decimal(12 * unitCount)
            print("Unit Count Year", unitCount)
        case .week:
            monthlyPrice = price * Decimal(52) / Decimal(12 * unitCount)
            print("Unit Count Week", unitCount)
        case .day:
            monthlyPrice = price * Decimal(4)
            print("Unit Count Day", unitCount)
        @unknown default:
            monthlyPrice = price
        }
        
        // Format the price
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        
        return formatter.string(from: monthlyPrice as NSDecimalNumber) ?? ""
    }
    private func getSubscriptionDescription() -> String {
        guard let subscription = product.subscription else { return "" }
        
        let unit = subscription.subscriptionPeriod.unit
        
        switch unit {
        case .month:
            return "Pro access with all features. Renews monthly."
        case .week:
            return "Pro access with all features. Renews weekly."
        case .day:
            return "Pro access with all features. Renews daily."
        case .year:
            return "Pro access with all features. Renews yearly."
        @unknown default:
            return "No description"
        }
    }
}

// MARK: - PREMIUM BUTTON
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
                .font(.system(size: 14, weight: .semibold, design: .rounded)) // Reduced font size
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 16) // Reduced horizontal padding
                .padding(.vertical, 10)   // Slightly reduced vertical padding
                .frame(maxWidth: .infinity) // Allow button to take available width
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

#Preview {
    SubscriptionView()
}
