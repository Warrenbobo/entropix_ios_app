//
//  LMScoreDonutOverlayView.swift
//  processor
//

import UIKit

/// Draggable 72×72 score donut overlay.
final class LMScoreDonutOverlayView: UIView {
    private let donutView = LMConcentricScoreDonutView()
    private var panStart: CGPoint = .zero
    var onDragBegan: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        addSubview(donutView)
        donutView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            donutView.centerXAnchor.constraint(equalTo: centerXAnchor),
            donutView.centerYAnchor.constraint(equalTo: centerYAnchor),
            donutView.widthAnchor.constraint(equalToConstant: 64),
            donutView.heightAnchor.constraint(equalToConstant: 64),
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        isAccessibilityElement = true
        accessibilityLabel = "Composition score"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(score: LMCompositionScore?) {
        donutView.apply(score: score)
    }

    func setVisible(_ visible: Bool) {
        isHidden = !visible
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview else { return }
        switch gesture.state {
        case .began:
            panStart = center
            onDragBegan?()
        case .changed:
            let translation = gesture.translation(in: superview)
            var newCenter = CGPoint(x: panStart.x + translation.x, y: panStart.y + translation.y)
            let margin: CGFloat = 8
            let half: CGFloat = 36
            newCenter.x = max(half + margin, min(superview.bounds.width - half - margin, newCenter.x))
            newCenter.y = max(half + margin, min(superview.bounds.height - half - margin, newCenter.y))
            center = newCenter
        default:
            break
        }
    }
}
