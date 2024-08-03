//
//  PaywallView.swift
//  clipboardManager
//
//  Created by muratcankoc on 22/07/2024.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @State private var isAnimating = false
    @StateObject private var purchaseManager = PurchaseManager()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            // Floating clipboard icons
            ForEach(0..<5) { index in
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.7))
                    .offset(x: CGFloat.random(in: -150...150), y: CGFloat.random(in: -300...300))
                    .animation(Animation.easeInOut(duration: Double.random(in: 2...4)).repeatForever(autoreverses: true).delay(Double.random(in: 0...2)), value: isAnimating)
            }
            
            VStack(spacing: 30) {
                Text("Get Access Now!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Unlimited clipboard history")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 15) {
                    Text("First 3 days free")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Then $0.99/month")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Button(action: {
                    purchaseManager.purchase()
                }) {
                    Text("Start Free Trial")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: 250, height: 60)
                        .background(Color.white)
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 20)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Handle restore purchases
                    purchaseManager.restorePurchases()
                }) {
                    Text("Restore Purchases")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .underline()
                }
                .padding(.top, 10)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
    }
}
