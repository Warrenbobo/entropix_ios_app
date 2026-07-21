//
//  LMUploadReferenceCardView.swift
//  processor
//

import UIKit
import SnapKit

/// Album upload card at carousel index 0 (parity with Android UploadReferenceCard).
final class LMUploadReferenceCardView: UIView {

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let dashedBorderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = UIColor(white: 0.2, alpha: 0.6)
        layer.cornerRadius = 12
        clipsToBounds = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: symbolConfig)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        titleLabel.text = LMLaunageManager.shared.camera.selectReferenceFromAlbum
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 3

        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(28)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(8)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isAccessibilityElement = true
        accessibilityLabel = titleLabel.text
        accessibilityTraits = .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashedBorderLayer.frame = bounds
        dashedBorderLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard dashedBorderLayer.superlayer == nil else { return }
        dashedBorderLayer.strokeColor = UIColor.white.cgColor
        dashedBorderLayer.fillColor = UIColor.clear.cgColor
        dashedBorderLayer.lineWidth = 1.5
        dashedBorderLayer.lineDashPattern = [8, 6]
        layer.addSublayer(dashedBorderLayer)
    }

    func applySelectionStyle(isSelected: Bool, borderWidth: CGFloat) {
        if isSelected {
            layer.borderWidth = borderWidth
            layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor = nil
        }
    }

    @objc private func handleTap() {
        onTap?()
    }
}
