//
//  LMGalleryMenuView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMGalleryMenuView: UIView {
    
    var galleryButtonAction: (() -> Void)?
    var savedIdeasButtonAction: (() -> Void)?
    
    
    func setSelectedTab(_ tab: TabType) {
        selectedTab = tab
    }
    
    func setGalleryButtonAction(_ action: @escaping () -> Void) {
        self.galleryButtonAction = action
    }
    
    func setSavedIdeasButtonAction(_ action: @escaping () -> Void) {
        self.savedIdeasButtonAction = action
    }
    
    
    enum TabType {
        case gallery
        case savedIdeas
    }
    
    private let galleryButton = UIButton()
    private let savedIdeasButton = UIButton()
    private let tabIndicator = UIView()
    
    private var selectedTab: TabType = .gallery {
        didSet {
            updateTabAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPhotoGalleryMenuContentViews()
        setupConstraints()
        updateTabAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPhotoGalleryMenuContentViews() {
        addSubview(galleryButton)
        addSubview(savedIdeasButton)
        addSubview(tabIndicator)
        
        galleryButton.setTitle("Gallery", for: .normal)
        galleryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        
        savedIdeasButton.setTitle("Saved Ideas", for: .normal)
        savedIdeasButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        savedIdeasButton.addTarget(self, action: #selector(savedIdeasButtonTapped), for: .touchUpInside)
        
        tabIndicator.backgroundColor = UIColor.systemBlue
        tabIndicator.layer.cornerRadius = 1
    }
    
    private func setupConstraints() {
        galleryButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(80)
        }
        savedIdeasButton.snp.makeConstraints { make in
            make.leading.equalTo(galleryButton.snp.trailing).offset(32)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(100)
        }
        tabIndicator.snp.makeConstraints { make in
            make.leading.equalTo(galleryButton)
            make.bottom.equalToSuperview()
            make.width.equalTo(galleryButton)
            make.height.equalTo(2)
        }
        self.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
    }
    
    private func updateTabAppearance() {
        switch selectedTab {
        case .gallery:
            galleryButton.setTitleColor(UIColor.systemBlue, for: .normal)
            savedIdeasButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
            
            tabIndicator.snp.remakeConstraints { make in
                make.leading.equalTo(galleryButton)
                make.bottom.equalToSuperview()
                make.width.equalTo(galleryButton)
                make.height.equalTo(2)
            }
        case .savedIdeas:
            galleryButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
            savedIdeasButton.setTitleColor(UIColor.systemBlue, for: .normal)
            
            tabIndicator.snp.remakeConstraints { make in
                make.leading.equalTo(savedIdeasButton)
                make.bottom.equalToSuperview()
                make.width.equalTo(savedIdeasButton)
                make.height.equalTo(2)
            }
        }
        
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    
    @objc private func galleryButtonTapped() {
        selectedTab = .gallery
        galleryButtonAction?()
    }
    
    @objc private func savedIdeasButtonTapped() {
        selectedTab = .savedIdeas
        savedIdeasButtonAction?()
    }
}
