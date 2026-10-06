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
    /// Returns the rect (in superview coordinates) the donut center may occupy while dragging.
    var allowedDragBoundsProvider: (() -> CGRect)?

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

    /**
     Clamps `point` so the donut stays inside the allowed drag window.

     Falls back to an 8pt inset of the superview when no provider is set.
     */
    func clampCenter(_ point: CGPoint) -> CGPoint {
        guard let superview else { return point }
        let half = bounds.width > 0 ? bounds.width / 2 : 36
        let margin: CGFloat = 8
        let fallback = superview.bounds.insetBy(dx: half + margin, dy: half + margin)
        var allowed = allowedDragBoundsProvider?() ?? fallback
        if allowed.isNull || allowed.isEmpty || allowed.width < 1 || allowed.height < 1 {
            allowed = fallback
        }
        let minX = allowed.minX
        let maxX = max(minX, allowed.maxX)
        let minY = allowed.minY
        let maxY = max(minY, allowed.maxY)
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview else { return }
        switch gesture.state {
        case .began:
            panStart = center
            onDragBegan?()
            // Re-clamp immediately so a stale position (e.g. after HUD layout) is corrected.
            center = clampCenter(center)
            panStart = center
        case .changed:
            let translation = gesture.translation(in: superview)
            let proposed = CGPoint(x: panStart.x + translation.x, y: panStart.y + translation.y)
            center = clampCenter(proposed)
        case .ended, .cancelled:
            center = clampCenter(center)
        default:
            break
        }
    }
}
