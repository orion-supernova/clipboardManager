//
//  PanelGlass.swift
//  clipboardManager
//
//  One place that decides how "glass" is drawn. Live UI uses Liquid Glass; the
//  offline marketing renderer (which cannot sample a backdrop) gets a frosted
//  stand-in so the very same views can be rendered to PNG/GIF.
//

import SwiftUI

extension EnvironmentValues {
    /// True while rendering marketing artwork with `ImageRenderer`.
    @Entry var marketingRender = false
    /// Pre-decoded images keyed by file path / "app:<bundle id>", used by offline renders.
    @Entry var staticImages: [String: CGImage] = [:]
    /// Horizontal offset applied to the selection ring while rendering GIF frames.
    @Entry var marketingRingOffset: CGFloat = 0
    /// 0…1 reveal progress of the quick-preview sheet while rendering GIF frames.
    @Entry var marketingSheetProgress: CGFloat = 1
}

private struct PanelGlassModifier<S: Shape>: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let prominent: Bool
    let shape: S
    @Environment(\.marketingRender) private var marketingRender
    /// Liquid Glass is precisely what "Reduce Transparency" exists to switch
    /// off: a translucent panel over an arbitrary desktop is unreadable for a
    /// lot of people. Honour it with a solid surface rather than a thinner blur.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background {
                    ZStack {
                        shape.fill(Color(nsColor: .windowBackgroundColor))
                        if let tint { shape.fill(tint.opacity(prominent ? 0.85 : 0.22)) }
                    }
                }
                .overlay(shape.stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                .clipShape(shape)
        } else if marketingRender {
            content
                .background {
                    ZStack {
                        shape.fill(.black.opacity(prominent ? 0.62 : 0.06))
                        shape.fill(.white.opacity(prominent ? 0.20 : 0.22))
                        if let tint { shape.fill(tint.opacity(0.45)) }
                    }
                }
                .overlay(shape.stroke(.white.opacity(0.42), lineWidth: 1))
                .clipShape(shape)
                .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        } else {
            content.glassEffect(liveGlass, in: shape)
        }
    }

    private var liveGlass: Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

private struct PanelButtonStyleModifier: ViewModifier {
    let prominent: Bool
    @Environment(\.marketingRender) private var marketingRender

    func body(content: Content) -> some View {
        if marketingRender {
            if prominent { content.buttonStyle(.borderedProminent) } else { content.buttonStyle(.bordered) }
        } else {
            if prominent { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.glass) }
        }
    }
}

extension View {
    func panelGlass(tint: Color? = nil, interactive: Bool = false, prominent: Bool = false, in shape: some Shape) -> some View {
        modifier(PanelGlassModifier(tint: tint, interactive: interactive, prominent: prominent, shape: shape))
    }

    func panelButtonStyle(prominent: Bool = false) -> some View {
        modifier(PanelButtonStyleModifier(prominent: prominent))
    }
}
