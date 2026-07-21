//
//  LMConcentricScoreDonutView.swift
//  processor
//

import UIKit

/// Three-ring score donut (S_global / S_geometric / S_human).
final class LMConcentricScoreDonutView: UIView {
    private let globalRing = CAShapeLayer()
    private let geometricRing = CAShapeLayer()
    private let humanRing = CAShapeLayer()
    private let globalTrack = CAShapeLayer()
    private let geometricTrack = CAShapeLayer()
    private let humanTrack = CAShapeLayer()
    private let centerLabel = UILabel()

    private static let trackColor = UIColor.white.withAlphaComponent(0.12).cgColor
    private static let humanGrayColor = UIColor.systemGray.cgColor

    override init(frame: CGRect) {
        super.init(frame: frame)
        [globalTrack, geometricTrack, humanTrack, globalRing, geometricRing, humanRing].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.lineWidth = 3
            $0.lineCap = .round
            layer.addSublayer($0)
        }
        [globalTrack, geometricTrack, humanTrack].forEach { $0.strokeColor = Self.trackColor }
        globalRing.strokeColor = UIColor.systemBlue.cgColor
        geometricRing.strokeColor = UIColor.systemTeal.cgColor
        humanRing.strokeColor = UIColor.systemOrange.cgColor

        centerLabel.font = .systemFont(ofSize: 14, weight: .bold)
        centerLabel.textColor = .white
        centerLabel.textAlignment = .center
        addSubview(centerLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        centerLabel.frame = bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        layoutTrack(globalTrack, center: center, radius: bounds.width * 0.46)
        layoutTrack(geometricTrack, center: center, radius: bounds.width * 0.36)
        layoutTrack(humanTrack, center: center, radius: bounds.width * 0.26)
        layoutRing(globalRing, center: center, radius: bounds.width * 0.46, progress: globalProgress, color: UIColor.systemBlue.cgColor)
        layoutRing(geometricRing, center: center, radius: bounds.width * 0.36, progress: geometricProgress, color: UIColor.systemTeal.cgColor)
        layoutRing(
            humanRing,
            center: center,
            radius: bounds.width * 0.26,
            progress: humanHasPerson ? humanProgress : 0,
            color: humanHasPerson ? UIColor.systemOrange.cgColor : Self.humanGrayColor
        )
    }

    private var globalProgress: CGFloat = 0
    private var geometricProgress: CGFloat = 0
    private var humanProgress: CGFloat = 0
    private var humanHasPerson = false

    func apply(score: LMCompositionScore?) {
        guard let score else {
            centerLabel.text = "--"
            globalProgress = 0
            geometricProgress = 0
            humanProgress = 0
            humanHasPerson = false
            setNeedsLayout()
            return
        }
        let overallPercent = Int(score.overallScore * 100)
        centerLabel.text = "\(overallPercent)"
        globalProgress = CGFloat(score.globalStructure)
        geometricProgress = CGFloat(score.geometric)
        humanHasPerson = score.humanScene != nil
        humanProgress = humanHasPerson ? CGFloat(score.humanScene ?? 0) : 0
        setNeedsLayout()
    }

    private func layoutTrack(_ ring: CAShapeLayer, center: CGPoint, radius: CGFloat) {
        ring.path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        ).cgPath
    }

    private func layoutRing(
        _ ring: CAShapeLayer,
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        color: CGColor
    ) {
        ring.strokeColor = color
        let clamped = max(0, min(1, progress))
        guard clamped > 0 else {
            ring.path = nil
            return
        }
        let start = -CGFloat.pi / 2
        let end = start + clamped * 2 * .pi
        ring.path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: start,
            endAngle: end,
            clockwise: true
        ).cgPath
    }
}
