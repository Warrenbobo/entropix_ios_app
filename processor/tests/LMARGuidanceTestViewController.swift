//
//  LMARGuidanceTestViewController.swift
//  processor
//
//  AR Guidance 测试页面 - 用于测试人物检测和坐标转换
//

import UIKit
import PhotosUI

/// AR Guidance 测试页面
class LMARGuidanceTestViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        return sv
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AR Guidance 测试"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var selectImageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("选择图片", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .systemGray6
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        return iv
    }()
    
    private lazy var resultTextView: UITextView = {
        let tv = UITextView()
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.isEditable = false
        tv.backgroundColor = .systemGray6
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return tv
    }()
    
    private lazy var bboxOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private var bboxLayer: CAShapeLayer?
    
    // MARK: - Properties
    
    private var selectedImage: UIImage?
    private var testResult: ARGuidanceTestResult?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "AR Guidance 测试"
        
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(selectImageButton)
        contentView.addSubview(imageView)
        contentView.addSubview(bboxOverlayView)
        contentView.addSubview(resultTextView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        selectImageButton.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        bboxOverlayView.translatesAutoresizingMaskIntoConstraints = false
        resultTextView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            selectImageButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            selectImageButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            selectImageButton.widthAnchor.constraint(equalToConstant: 200),
            selectImageButton.heightAnchor.constraint(equalToConstant: 50),
            
            imageView.topAnchor.constraint(equalTo: selectImageButton.bottomAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalToConstant: 300),
            
            bboxOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            bboxOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            bboxOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            bboxOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            resultTextView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            resultTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultTextView.heightAnchor.constraint(equalToConstant: 400),
            resultTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func selectImageTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Test
    
    private func runTest(with image: UIImage) {
        selectedImage = image
        imageView.image = image
        resultTextView.text = "正在测试..."
        
        // 清除之前的 bbox
        bboxLayer?.removeFromSuperlayer()
        bboxLayer = nil
        
        LMARGuidanceTestHelper.shared.testPersonDetection(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.testResult = result
                self?.resultTextView.text = result.generateReport()
                self?.drawBboxOverlay(result: result)
            }
        }
    }
    
    private func drawBboxOverlay(result: ARGuidanceTestResult) {
        guard let bbox = result.detectedBbox else { return }
        
        // 计算 imageView 中图片的实际显示区域
        guard let image = selectedImage else { return }
        
        let imageViewSize = imageView.bounds.size
        let imageSize = image.size
        
        // 计算 scaleAspectFit 后的实际显示尺寸
        let widthRatio = imageViewSize.width / imageSize.width
        let heightRatio = imageViewSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let displayWidth = imageSize.width * scale
        let displayHeight = imageSize.height * scale
        let displayX = (imageViewSize.width - displayWidth) / 2
        let displayY = (imageViewSize.height - displayHeight) / 2
        
        // 将 Vision bbox 转换到 imageView 坐标
        // Vision 坐标系：原点在左下角，Y轴向上
        let flippedY = 1.0 - bbox.origin.y - bbox.height
        
        let bboxX = displayX + bbox.origin.x * displayWidth
        let bboxY = displayY + flippedY * displayHeight
        let bboxWidth = bbox.width * displayWidth
        let bboxHeight = bbox.height * displayHeight
        
        let bboxRect = CGRect(x: bboxX, y: bboxY, width: bboxWidth, height: bboxHeight)
        
        // 绘制 bbox
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemGreen.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2
        layer.path = UIBezierPath(rect: bboxRect).cgPath
        
        // 添加中心点
        let centerX = bboxRect.midX
        let centerY = bboxRect.midY
        let crosshairSize: CGFloat = 10
        
        let crosshairPath = UIBezierPath()
        crosshairPath.move(to: CGPoint(x: centerX - crosshairSize, y: centerY))
        crosshairPath.addLine(to: CGPoint(x: centerX + crosshairSize, y: centerY))
        crosshairPath.move(to: CGPoint(x: centerX, y: centerY - crosshairSize))
        crosshairPath.addLine(to: CGPoint(x: centerX, y: centerY + crosshairSize))
        
        let crosshairLayer = CAShapeLayer()
        crosshairLayer.strokeColor = UIColor.systemRed.cgColor
        crosshairLayer.lineWidth = 2
        crosshairLayer.path = crosshairPath.cgPath
        
        bboxOverlayView.layer.addSublayer(layer)
        bboxOverlayView.layer.addSublayer(crosshairLayer)
        
        bboxLayer = layer
    }
}

// MARK: - PHPickerViewControllerDelegate

extension LMARGuidanceTestViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self?.runTest(with: image)
                }
            }
        }
    }
}

// MARK: - Quick Access

extension LMARGuidanceTestViewController {
    /// 快速打开测试页面
    static func present(from viewController: UIViewController) {
        let testVC = LMARGuidanceTestViewController()
        let nav = UINavigationController(rootViewController: testVC)
        nav.modalPresentationStyle = .fullScreen
        viewController.present(nav, animated: true)
    }
}
