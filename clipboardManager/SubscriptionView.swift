//
//  SubscriptionView.swift
//  clipboardManager
//
//  Created by muratcankoc on 08/11/2024.
//

import SwiftUI
import StoreKit


struct SubscriptionColors {
    static let gradient1 = Color(hex: "FF3CAC")
    static let gradient2 = Color(hex: "784BA0")
    static let gradient3 = Color(hex: "2B86C5")
    static let accent = Color(hex: "FFD700")  // Premium gold
    static let text = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "B8B8B8")
    static let cardBg = Color.black.opacity(0.2)
}

struct BackgroundView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base color
            Color(NSColor.windowBackgroundColor)
            
            // Animated gradient background
            LinearGradient(
                colors: [
                    SubscriptionColors.gradient1.opacity(0.15),
                    SubscriptionColors.gradient2.opacity(0.1),
                    SubscriptionColors.gradient3.opacity(0.05)
                ],
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            .blur(radius: 50)
            .onAppear {
                withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
            
            // Overlay pattern for texture
            Rectangle()
                .fill(
                    Color.black.opacity(0.03)
                )
                .allowsHitTesting(false)
        }
    }
}

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: Product?
    @State private var isAnimating = false
    @State private var showFeatures = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
            
            VStack(spacing: 30) {
                // Premium Badge
                premiumBadge
                    .offset(y: isAnimating ? 0 : -50)
                    .opacity(isAnimating ? 1 : 0)
                
                // Features Grid
                featuresSection
                    .offset(y: isAnimating ? 0 : 50)
                    .opacity(isAnimating ? 1 : 0)
                
                // Subscription Plan
                if subscriptionManager.subscriptions.isEmpty {
                    loadingView
                } else {
                    subscriptionPlan
                        .offset(y: isAnimating ? 0 : 50)
                        .opacity(isAnimating ? 1 : 0)
                }
                
                // Footer
                footerSection
                    .offset(y: isAnimating ? 0 : 30)
                    .opacity(isAnimating ? 1 : 0)
            }
            .padding(40)
        }
        .frame(width: 800, height: 500)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                isAnimating = true
            }
            withAnimation(.easeInOut.delay(0.3)) {
                showFeatures = true
            }
        }
    }
    
    private var premiumBadge: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(["✨", "⚡️", "🚀"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 24))
                        .modifier(FloatingAnimation(delay: Double(emoji.count) * 0.2))
                }
            }
            
            Text("Unlock Premium Features")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, SubscriptionColors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    private var featuresSection: some View {
        HStack(spacing: 25) {
            ForEach(PremiumFeature.allCases, id: \.title) { feature in
                FeatureCard(feature: feature, isVisible: showFeatures)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 15) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Subscriptions...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private var subscriptionPlan: some View {
        VStack(spacing: 20) {
            ForEach(subscriptionManager.subscriptions, id: \.id) { product in
                SubscriptionPlanCard(
                    product: product,
                    isSelected: selectedPlan?.id == product.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        HStack {
            Text("Cancel anytime during trial period")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(SubscriptionColors.textSecondary)
            
            Spacer()
            
            Button(action: {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }) {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SubscriptionColors.gradient1)
            }
            .buttonStyle(.plain)
        }
    }
}

struct AnimatedGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        LinearGradient(
            colors: [
                SubscriptionColors.gradient1,
                SubscriptionColors.gradient2,
                SubscriptionColors.gradient3
            ],
            startPoint: animate ? .topLeading : .bottomLeading,
            endPoint: animate ? .bottomTrailing : .topTrailing
        )
        .blur(radius: 50)
        .overlay(
            ZStack {
                // Animated particles
                ParticlesView()
                    .opacity(0.4)
                
                // Noise texture
                Image("noise")
                    .resizable()
                    .opacity(0.05)
            }
        )
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

enum PremiumFeature: CaseIterable {
    case unlimited, search, keyboard
    
    var title: String {
        switch self {
        case .unlimited: return "Unlimited History"
        case .search: return "Smart Search"
        case .keyboard: return "Keyboard Navigation"
        }
    }
    
    var icon: String {
        switch self {
        case .unlimited: return "infinity"
        case .search: return "magnifyingglass.circle.fill"
        case .keyboard: return "keyboard.fill"
        }
    }
    
    var description: String {
        switch self {
        case .unlimited: return "Never lose any copied item"
        case .search: return "Find anything instantly"
        case .keyboard: return "Lightning-fast access"
        }
    }
}

struct FeatureCard: View {
    let feature: PremiumFeature
    let isVisible: Bool
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: feature.icon)
                .font(.system(size: 30))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, SubscriptionColors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .background(
                    ZStack {
                        Circle()
                            .fill(SubscriptionColors.cardBg)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
            Text(feature.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Text(feature.description)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(SubscriptionColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SubscriptionColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(feature.title.count) * 0.1), value: isVisible)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

struct RestoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(SubscriptionColors.gradient1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SubscriptionColors.gradient1.opacity(0.5), lineWidth: 1)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// Add this modifier for floating animation
struct FloatingAnimation: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    
    init(delay: Double = 0) {
        self.delay = delay
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -5 : 5)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    isAnimating = true
                }
            }
    }
}

// Add a particles view for background animation
struct ParticlesView: View {
    @State private var phase = 0.0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let timeNow = timeline.date.timeIntervalSinceReferenceDate
                let phase = timeNow.remainder(dividingBy: 10)
                
                context.opacity = 0.3
                
                for i in 0..<50 {
                    let position = position(index: i, phase: phase, size: size)
                    let path = Path(ellipseIn: CGRect(x: position.x, y: position.y, width: 4, height: 4))
                    context.fill(path, with: .color(.white))
                }
            }
        }
    }
    
    func position(index: Int, phase: Double, size: CGSize) -> CGPoint {
        let angle = Double(index) * 0.5 + phase
        let x = sin(angle) * 100 + size.width / 2
        let y = cos(angle) * 100 + size.height / 2
        return CGPoint(x: x, y: y)
    }
}

// Add visual effect blur view
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

extension SubscriptionView {
    func benefitTitle(for emoji: String) -> String {
        switch emoji {
        case "∞":
            return "Unlimited Items"
        case "⚡️":
            return "Quick Access"
        case "🔍":
            return "Smart Search"
        default:
            return ""
        }
    }
}

// Add SubscriptionPlanCard
struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(product.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(product.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
                Text("Includes 3-day free trial")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(SubscriptionColors.accent)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("after trial")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(SubscriptionColors.textSecondary)
            }
            
            Button(action: onPurchase) {
                Text("Start Free Trial")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                SubscriptionColors.gradient1,
                                SubscriptionColors.gradient2
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 2 : 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onSelect)
    }
}
