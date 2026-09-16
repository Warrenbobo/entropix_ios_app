//
//  LMFloatingCameraButton 2.swift
//  processor
//
//  Created by muz on 2025/9/20.
//


import UIKit
import SnapKit

class LMFloatingCameraButton: UIView {
    
    var cameraButtonAction: (() -> Void)?
    
    func setCameraButtonAction(_ action: @escaping () -> Void) {
        self.cameraButtonAction = action
    }
    
    func setButtonColor(_ color: UIColor) {
        cameraButton.backgroundColor = color
    }
    
    private let cameraButton = UIButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // 设置渐变背景
        setupGradientBackground()
        setupTheFloatCameraButtonViews()
        // 添加阴影
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTheFloatCameraButtonViews() {
        addSubview(cameraButton)
        
        // 设置相机图标
        cameraButton.setImage(UIImage.lmSymbol("camera.fill", pointSize: 22), for: .normal)
        cameraButton.tintColor = UIColor.white
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 13, left: 13, bottom: 13, right: 13)
        cameraButton.adjustsImageWhenHighlighted = false
        
        cameraButton.layer.cornerRadius = 20
        cameraButton.layer.borderColor = UIColor.white.cgColor
        cameraButton.layer.borderWidth = 2
        cameraButton.layer.masksToBounds = true
        
        // 添加约束
        cameraButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupGradientBackground() {
        let gradientImageView = UIImageView()
        let gradientImage = UIImage.gradientImage(size: CGSize(width: 60, height: 60),
                                                  colors: [UIColor.hexColor("#6680E6").cgColor,
                                                           UIColor.hexColor("#9966E6").cgColor],
                                                  cornerRadius: 20)
        gradientImageView.image = gradientImage
        addSubview(gradientImageView)
        gradientImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @objc private func cameraButtonTapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.cameraButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.cameraButton.transform = CGAffineTransform.identity
            }
        }
        cameraButtonAction?()
    }
}
