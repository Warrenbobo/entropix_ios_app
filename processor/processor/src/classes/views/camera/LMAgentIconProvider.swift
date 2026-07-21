//
//  LMAgentIconProvider.swift
//  processor
//

import UIKit

/// Centralized agent / instruct icon access (parity §6.2.0).
enum LMAgentIconProvider {

    /// Matches Android bottom instruct icon; enlarged for visibility.
    static let instructIconPointSize: CGFloat = 38

    private static let instructIconDimmedAlphaScale: CGFloat = 0.58

    static var agentToggleIcon: UIImage? {
        UIImage(named: "ai_agent_stroke")?.withRenderingMode(.alwaysTemplate)
    }

    /// Shutter instruct icon — SF Symbol with Agent accent gradient (Android `IntelligentGradientIcon`).
    static func instructIcon(dimmed: Bool = false) -> UIImage? {
        let scale = dimmed ? instructIconDimmedAlphaScale : 1
        let colors = LMLiquidGlassHUDTokens.agentAccentBorderColors.map {
            $0.withAlphaComponent($0.cgColor.alpha * scale)
        }
        return makeGradientSymbolImage(
            systemName: "apple.intelligence",
            pointSize: instructIconPointSize,
            weight: .medium,
            colors: colors
        )
    }

    private static func makeGradientSymbolImage(
        systemName: String,
        pointSize: CGFloat,
        weight: UIImage.SymbolWeight,
        colors: [UIColor]
    ) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        guard let symbol = UIImage(systemName: systemName, withConfiguration: configuration) else {
            return nil
        }

        let size = symbol.size
        guard size.width > 0, size.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            symbol.withTintColor(.black, renderingMode: .alwaysOriginal).draw(in: rect)

            context.cgContext.setBlendMode(.sourceIn)
            let cgColors = colors.map(\.cgColor) as CFArray
            let locations: [CGFloat] = [0, 0.5, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors,
                locations: locations
            ) else { return }

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height * 0.5),
                end: CGPoint(x: size.width, y: size.height * 0.5),
                options: []
            )
        }
    }
}
