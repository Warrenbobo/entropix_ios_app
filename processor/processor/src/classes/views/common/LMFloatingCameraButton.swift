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
        setupTheFloatCameraButtonViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTheFloatCameraButtonViews() {
        addSubview(cameraButton)
        
        cameraButton.backgroundColor = UIColor.systemBlue
        cameraButton.layer.cornerRadius = 25
        cameraButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        cameraButton.tintColor = UIColor.white
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
        
        // 添加阴影
        cameraButton.layer.shadowColor = UIColor.black.cgColor
        cameraButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        cameraButton.layer.shadowRadius = 8
        cameraButton.layer.shadowOpacity = 0.2
        
        // 添加约束
        cameraButton.snp.makeConstraints { make in
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
