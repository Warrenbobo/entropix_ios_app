//
//  LMPreShootPlanModeSheet.swift
//  processor
//
//  Mode picker: 1-column × 3-row list expanding downward from the mode chip.
//

import UIKit
import SnapKit

protocol LMPreShootPlanModeSheetDelegate: AnyObject {
    func preShootPlanModeSheetDidSelect(_ mode: LMPreShootPlanMode)
    func preShootPlanModeSheetDidDismiss()
}

/// Fullscreen dimmed overlay with a vertical mode panel below the top mode chip.
final class LMPreShootPlanModeSheet: UIView {

    weak var delegate: LMPreShootPlanModeSheetDelegate?

    private let dimView = UIControl()
    private let modePanel = LMPreShootPlanModePanelView(isInteractive: true, selected: .findSpot)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Shows the sheet in `host`, anchoring the panel below `anchor`.

     - Parameters:
       - host: Parent view (typically the camera page view).
       - anchor: Mode chip frame in host coordinates.
       - selected: Currently selected mode.
     */
    func present(in host: UIView, below anchor: UIView, selected: LMPreShootPlanMode) {
        modePanel.setSelected(selected)
        frame = host.bounds
        host.addSubview(self)
        snp.makeConstraints { $0.edges.equalToSuperview() }

        let anchorFrame = anchor.convert(anchor.bounds, to: host)
        modePanel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(220)
            make.top.equalToSuperview().offset(anchorFrame.maxY + 8)
        }
        alpha = 0
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    /// Compatibility: older call sites anchored “above” the shutter-area button.
    func present(in host: UIView, above anchor: UIView, selected: LMPreShootPlanMode) {
        present(in: host, below: anchor, selected: selected)
    }

    func dismiss() {
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
            self.delegate?.preShootPlanModeSheetDidDismiss()
        }
    }
}

private extension LMPreShootPlanModeSheet {

    func setup() {
        addSubview(dimView)
        addSubview(modePanel)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.addTarget(self, action: #selector(handleDim), for: .touchUpInside)
        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }

        modePanel.onSelect = { [weak self] mode in
            self?.delegate?.preShootPlanModeSheetDidSelect(mode)
            self?.dismiss()
        }
    }

    @objc func handleDim() { dismiss() }
}
