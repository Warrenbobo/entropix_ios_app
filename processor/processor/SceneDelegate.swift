//
//  SceneDelegate.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import CoreVideo

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
#if DEBUG
    private var arGuidanceRuntimeHarness: LMARGuidanceRuntimeHarness?
    private var processingRuntimeHarness: LMProcessingRuntimeHarness?
    private var inspireMeTapRuntimeHarness: LMInspireMeTapRuntimeHarness?
#endif

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        window?.frame = UIScreen.main.bounds
        window?.backgroundColor = .white
        LMPackageManager.window = window
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--processing-runtime-harness") {
            let cameraPage = LMCameraPage()
            let navigationController = LMNavigationWrapper(rootViewController: cameraPage)
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()

            let harness = LMProcessingRuntimeHarness(cameraPage: cameraPage)
            processingRuntimeHarness = harness
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                harness.start()
            }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--arguidance-runtime-harness") {
            let cameraPage = LMCameraPage()
            let navigationController = LMNavigationWrapper(rootViewController: cameraPage)
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()

            let harness = LMARGuidanceRuntimeHarness(cameraPage: cameraPage)
            arGuidanceRuntimeHarness = harness
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                harness.start()
            }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--inspireme-runtime-harness") {
            let cameraPage = LMCameraPage()
            let navigationController = LMNavigationWrapper(rootViewController: cameraPage)
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()

            let harness = LMInspireMeTapRuntimeHarness(cameraPage: cameraPage)
            inspireMeTapRuntimeHarness = harness
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                harness.start()
            }
            return
        }
#endif
        let launchSplash = LMLaunchSplashPage()
        window?.rootViewController = launchSplash
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }

    func sceneWillResignActive(_ scene: UIScene) {
        
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        
        LMPhotoStorageManager.shared.saveContext()
    }


}

#if DEBUG
private final class LMInspireMeTapRuntimeHarness {
    private weak var cameraPage: LMCameraPage?
    private let statusView = UITextView()
    private var failures: [String] = []
    private var eventLog: [String] = []

    init(cameraPage: LMCameraPage) {
        self.cameraPage = cameraPage
    }

    @MainActor
    func start() {
        guard let cameraPage else { return }
        attachOverlay(to: cameraPage.view)
        log("start")

        Task { @MainActor [weak self] in
            await self?.run()
        }
    }

    @MainActor
    private func run() async {
        guard let cameraPage else { return }

        let sampleImage = makeFrozenFrameImage(size: CGSize(width: 960, height: 1280))
        guard let pixelBuffer = makePixelBuffer(from: sampleImage) else {
            assertCondition(false, "pixel buffer created from synthetic frame")
            finish()
            return
        }

        cameraPage.guideView?.hideTutorial(animated: false)
        cameraPage.guideView?.isHidden = true
        cameraPage.debugShouldBypassInspireMePermissionCheck = true
        cameraPage.debugShouldTreatInspireMeCaptureSessionAsRunning = true
        cameraPage.debugInspireMeSceneFeatureOverride = { _ in [0.12, 0.34, 0.56] }
        cameraPage.debugInspireMeCompositionSubmitter = { _, _, _, _, completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion(
                    LMApiResponseModel<LMCompositionTaskResponse>(
                        value: nil,
                        code: 500,
                        status: nil,
                        message: "debug synthetic completion",
                        rawData: nil
                    )
                )
            }
        }

        cameraPage.updateInspireMeButtonState()
        cameraPage.cacheLatestPreviewPixelBuffer(pixelBuffer)
        let expectedFrozenFrame = cameraPage.makeInspireMeImage(from: pixelBuffer, deviceOrientation: .portrait)

        cameraPage.inspireMeButtonViewDidTapButton()
        cameraPage.view.layoutIfNeeded()

        let immediateSnapshot = cameraPage.debugProcessingSnapshot()
        assertCondition(cameraPage.isInspireMeCapture, "processing flag set immediately")
        assertCondition(immediateSnapshot.overlayVisible, "overlay visible immediately after tap")
        assertCondition(!cameraPage.shouldCaptureNextFrame, "next-frame fallback not armed when cache exists")
        assertCondition(
            imageFingerprint(cameraPage.currentProcessingSceneryImage) == imageFingerprint(expectedFrozenFrame),
            "frozen frame matches cached preview frame"
        )

        await wait(seconds: 0.45)

        let completionSnapshot = cameraPage.debugProcessingSnapshot()
        assertCondition(!completionSnapshot.overlayVisible, "overlay removed after synthetic completion")
        assertCondition(!cameraPage.isInspireMeCapture, "processing flag reset after synthetic completion")

        finish()
    }

    @MainActor
    private func finish() {
        if failures.isEmpty {
            log("RESULT PASS")
            statusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
        } else {
            log("RESULT FAIL count=\(failures.count)")
            statusView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
        }
    }

    @MainActor
    private func attachOverlay(to view: UIView) {
        guard statusView.superview == nil else { return }

        statusView.isEditable = false
        statusView.isSelectable = false
        statusView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        statusView.textColor = .white
        statusView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusView.layer.cornerRadius = 10
        statusView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        statusView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            statusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusView.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    @MainActor
    private func assertCondition(_ condition: Bool, _ message: String) {
        if condition {
            log("PASS \(message)")
        } else {
            failures.append(message)
            log("FAIL \(message)")
        }
    }

    @MainActor
    private func log(_ message: String) {
        let line = "[InspireMeTapHarness] \(message)"
        eventLog.append(line)
        if eventLog.count > 18 {
            eventLog.removeFirst(eventLog.count - 18)
        }
        statusView.text = eventLog.joined(separator: "\n")
        print(line)
    }

    private func makeFrozenFrameImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.systemYellow.setFill()
            UIBezierPath(ovalIn: CGRect(x: 140, y: 180, width: 220, height: 220)).fill()

            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 480, y: 240, width: 280, height: 520))

            UIColor.systemTeal.setStroke()
            let strokePath = UIBezierPath()
            strokePath.lineWidth = 28
            strokePath.move(to: CGPoint(x: 90, y: 1100))
            strokePath.addLine(to: CGPoint(x: 880, y: 860))
            strokePath.stroke()
        }
    }

    private func makePixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let normalizedImage = image.lmNormalizedImage()
        guard let cgImage = normalizedImage.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    private func imageFingerprint(_ image: UIImage?) -> String? {
        image?.lmNormalizedImage().pngData()?.base64EncodedString()
    }

    @MainActor
    private func wait(seconds: TimeInterval) async {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private final class LMProcessingRuntimeHarness {
    private weak var cameraPage: LMCameraPage?
    private let statusView = UITextView()
    private var failures: [String] = []
    private var eventLog: [String] = []

    init(cameraPage: LMCameraPage) {
        self.cameraPage = cameraPage
    }

    @MainActor
    func start() {
        guard let cameraPage else { return }
        attachOverlay(to: cameraPage.view)
        log("start")

        Task { @MainActor [weak self] in
            await self?.run()
        }
    }

    @MainActor
    private func run() async {
        guard let cameraPage else { return }

        let sampleImage = makeProcessingImage(size: CGSize(width: 900, height: 1200))
        cameraPage.guideView?.hideTutorial(animated: false)
        cameraPage.guideView?.isHidden = true
        cameraPage.view.layoutIfNeeded()

        cameraPage.debugShowProcessingOverlay(with: sampleImage)
        await wait(seconds: 0.35)

        let visibleSnapshot = cameraPage.debugProcessingSnapshot()
        assertCondition(visibleSnapshot.overlayVisible, "overlay visible after show")
        assertCondition(visibleSnapshot.sceneryImageVisible, "scenery frame visible after show")
        assertCondition(visibleSnapshot.blurImageVisible, "blur image visible after show")
        assertCondition(abs(visibleSnapshot.dimmingAlpha - 0.6) < 0.01, "dimming alpha equals 0.6")
        assertCondition(visibleSnapshot.spinnerSize == CGSize(width: 40, height: 40), "spinner size equals 40x40")
        assertCondition(visibleSnapshot.spinnerStrokeWidth == 4, "spinner stroke width equals 4")
        assertCondition(visibleSnapshot.labelText == LMText.camera.processingInspiring, "label text matches processing copy")
        assertCondition(visibleSnapshot.labelFontSize == 18, "label font size equals 18")
        assertCondition(abs(visibleSnapshot.labelKerning - 0.5) < 0.01, "label kerning equals 0.5")
        assertCondition(visibleSnapshot.overlayFrame.width > 0 && visibleSnapshot.overlayFrame.height > 0, "overlay frame is non-zero")

        statusView.isHidden = true

        let snapshotURL = cameraPage.debugSaveVisibleProcessingSnapshot(named: "processing-runtime-visible.png")
        assertCondition(snapshotURL != nil, "in-app snapshot saved")

        log("SCREENSHOT READY")
        if let snapshotURL {
            log("SNAPSHOT FILE \(snapshotURL.path)")
        }
        await wait(seconds: 1.5)

        cameraPage.debugHideProcessingOverlayForRuntimeHarness()
        await wait(seconds: 0.35)

        let hiddenSnapshot = cameraPage.debugProcessingSnapshot()
        assertCondition(!hiddenSnapshot.overlayVisible, "overlay removed after hide")

        if failures.isEmpty {
            log("RESULT PASS")
            statusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
        } else {
            log("RESULT FAIL count=\(failures.count)")
            statusView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
        }
    }

    @MainActor
    private func attachOverlay(to view: UIView) {
        guard statusView.superview == nil else { return }

        statusView.isEditable = false
        statusView.isSelectable = false
        statusView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        statusView.textColor = .white
        statusView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusView.layer.cornerRadius = 10
        statusView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        statusView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            statusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusView.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    @MainActor
    private func assertCondition(_ condition: Bool, _ message: String) {
        if condition {
            log("PASS \(message)")
        } else {
            failures.append(message)
            log("FAIL \(message)")
        }
    }

    @MainActor
    private func log(_ message: String) {
        let line = "[ProcessingHarness] \(message)"
        eventLog.append(line)
        if eventLog.count > 18 {
            eventLog.removeFirst(eventLog.count - 18)
        }
        statusView.text = eventLog.joined(separator: "\n")
        print(line)
    }

    private func makeProcessingImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.14, green: 0.17, blue: 0.22, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let gradientColors = [
                UIColor(red: 0.93, green: 0.46, blue: 0.31, alpha: 1).cgColor,
                UIColor(red: 0.19, green: 0.58, blue: 0.96, alpha: 1).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: locations) else {
                return
            }

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    @MainActor
    private func wait(seconds: TimeInterval) async {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private final class LMARGuidanceRuntimeHarness {
    private weak var cameraPage: LMCameraPage?
    private let statusView = UITextView()
    private var failures: [String] = []
    private var eventLog: [String] = []

    init(cameraPage: LMCameraPage) {
        self.cameraPage = cameraPage
    }

    @MainActor
    func start() {
        guard let cameraPage else { return }
        attachOverlay(to: cameraPage.view)
        log("start")

        Task { @MainActor [weak self] in
            await self?.run()
        }
    }

    @MainActor
    private func run() async {
        guard let cameraPage else { return }

        let portraitReference = makeReferenceImage(size: CGSize(width: 600, height: 800), tint: .systemPink)
        let portraitLineArt = makeLineArtImage(size: portraitReference.size)
        let landscapeReference = makeReferenceImage(size: CGSize(width: 800, height: 600), tint: .systemTeal)
        let landscapeLineArt = makeLineArtImage(size: landscapeReference.size)

        await wait(seconds: 0.5)
        await runReentryScenario(
            name: "portrait-box",
            referenceImage: portraitReference,
            lineArtImage: portraitLineArt,
            bbox: CGRect(x: 0.24, y: 0.12, width: 0.42, height: 0.7),
            mode: .box,
            matchedOrientations: [.portrait],
            mismatchOrientation: .landscapeLeft,
            cycles: 3
        )
        await runReentryScenario(
            name: "portrait-lineart",
            referenceImage: portraitReference,
            lineArtImage: portraitLineArt,
            bbox: CGRect(x: 0.24, y: 0.12, width: 0.42, height: 0.7),
            mode: .lineArt,
            matchedOrientations: [.portrait],
            mismatchOrientation: .landscapeRight,
            cycles: 3
        )
        await runReentryScenario(
            name: "landscape-box",
            referenceImage: landscapeReference,
            lineArtImage: landscapeLineArt,
            bbox: CGRect(x: 0.2, y: 0.18, width: 0.5, height: 0.62),
            mode: .box,
            matchedOrientations: [.landscapeRight, .landscapeLeft],
            mismatchOrientation: .portrait,
            cycles: 2
        )
        await runReentryScenario(
            name: "landscape-lineart",
            referenceImage: landscapeReference,
            lineArtImage: landscapeLineArt,
            bbox: CGRect(x: 0.2, y: 0.18, width: 0.5, height: 0.62),
            mode: .lineArt,
            matchedOrientations: [.landscapeRight, .landscapeLeft],
            mismatchOrientation: .portrait,
            cycles: 2
        )

        cameraPage.closeReferenceImage()
        await wait(seconds: 0.6)

        if failures.isEmpty {
            log("RESULT PASS")
            statusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
        } else {
            log("RESULT FAIL count=\(failures.count)")
            statusView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
        }
    }

    @MainActor
    private func runReentryScenario(
        name: String,
        referenceImage: UIImage,
        lineArtImage: UIImage,
        bbox: CGRect,
        mode: LMARGuidanceButtonState,
        matchedOrientations: [UIDeviceOrientation],
        mismatchOrientation: UIDeviceOrientation,
        cycles: Int
    ) async {
        guard let cameraPage else { return }

        let suggestion = makeSuggestion(id: name, image: referenceImage)
        cameraPage.debugPrepareShowSuggestions(with: [suggestion])
        await wait(seconds: 0.2)
        cameraPage.preferredARGuidanceButtonState = mode

        for cycle in 1...cycles {
            log("\(name) cycle=\(cycle) enter")
            LMDeviceOrientationManager.shared.debugForceOrientation(matchedOrientations[0])
            await wait(seconds: 0.35)

            cameraPage.enterCompositionSelectedState(with: suggestion, image: referenceImage)
            await wait(seconds: 0.7)

            let enteredSnapshot = cameraPage.debugSnapshot()
            assertCondition(enteredSnapshot.referenceObserverActive, "\(name) cycle \(cycle): reference observer active after enter")
            assertCondition(enteredSnapshot.referenceImageVisible, "\(name) cycle \(cycle): reference image visible after enter")
            assertCondition(enteredSnapshot.preferredDisplayState == mode, "\(name) cycle \(cycle): preferred mode preserved on enter")
            if matchedOrientations[0].isPortrait {
                assertReferenceAngle(
                    name: "\(name) cycle \(cycle): matched enter rotation",
                    actual: enteredSnapshot.referenceImageAngle,
                    expected: expectedReferenceAngle(for: matchedOrientations[0])
                )
            }

            if mode == .lineArt {
                cameraPage.debugInjectSyntheticLineArtImage(lineArtImage)
                await wait(seconds: 0.15)
                let preReadySnapshot = cameraPage.debugSnapshot()
                assertCondition(preReadySnapshot.hasLineArtImage, "\(name) cycle \(cycle): lineArt image injected before ready")
                assertCondition(!preReadySnapshot.hasReferenceGuideReady, "\(name) cycle \(cycle): guide not ready before bbox")
                assertCondition(preReadySnapshot.lineArtHidden, "\(name) cycle \(cycle): lineArt hidden before guide ready")
            }

            cameraPage.debugInjectSyntheticGuidance(bbox: bbox, lineArtImage: lineArtImage)
            await wait(seconds: 0.25)
            assertGuidanceVisible(name: "\(name) cycle \(cycle): ready visible", mode: mode, snapshot: cameraPage.debugSnapshot())

            if matchedOrientations.count > 1 {
                for orientation in matchedOrientations.dropFirst() {
                    LMDeviceOrientationManager.shared.debugForceOrientation(orientation)
                    await wait(seconds: 0.45)
                    let sideSnapshot = cameraPage.debugSnapshot()
                    assertGuidanceVisible(name: "\(name) cycle \(cycle): alternate matched visible \(orientation.rawValue)", mode: mode, snapshot: sideSnapshot)
                    assertReferenceAngle(
                        name: "\(name) cycle \(cycle): alternate matched rotation \(orientation.rawValue)",
                        actual: sideSnapshot.referenceImageAngle,
                        expected: expectedReferenceAngle(for: orientation)
                    )
                    assertGuidanceAngle(
                        name: "\(name) cycle \(cycle): alternate matched guidance rotation \(orientation.rawValue)",
                        actual: sideSnapshot.guidanceViewAngle,
                        expected: expectedGuidanceAngle(
                            referenceImage: referenceImage,
                            orientation: orientation
                        )
                    )
                }
            }

            LMDeviceOrientationManager.shared.debugForceOrientation(mismatchOrientation)
            await wait(seconds: 0.45)
            assertGuidanceHidden(name: "\(name) cycle \(cycle): mismatch hidden", mode: mode, snapshot: cameraPage.debugSnapshot())

            let recoveryOrientation = matchedOrientations.last ?? matchedOrientations[0]
            LMDeviceOrientationManager.shared.debugForceOrientation(recoveryOrientation)
            await wait(seconds: 1.35)
            let recoveredSnapshot = cameraPage.debugSnapshot()
            assertGuidanceVisible(name: "\(name) cycle \(cycle): recovery visible", mode: mode, snapshot: recoveredSnapshot)
            assertReferenceAngle(
                name: "\(name) cycle \(cycle): recovery rotation",
                actual: recoveredSnapshot.referenceImageAngle,
                expected: expectedReferenceAngle(for: recoveryOrientation)
            )
            assertGuidanceAngle(
                name: "\(name) cycle \(cycle): recovery guidance rotation",
                actual: recoveredSnapshot.guidanceViewAngle,
                expected: expectedGuidanceAngle(
                    referenceImage: referenceImage,
                    orientation: recoveryOrientation
                )
            )

            cameraPage.closeReferenceImage()
            await wait(seconds: 0.65)
            let closedSnapshot = cameraPage.debugSnapshot()
            assertCondition(!closedSnapshot.referenceObserverActive, "\(name) cycle \(cycle): reference observer removed after close")
            assertCondition(!closedSnapshot.referenceImageVisible, "\(name) cycle \(cycle): reference image hidden after close")
            assertCondition(closedSnapshot.referenceBoxHidden, "\(name) cycle \(cycle): reference box hidden after close")
            assertCondition(closedSnapshot.lineArtHidden, "\(name) cycle \(cycle): lineArt hidden after close")
            assertCondition(closedSnapshot.preferredDisplayState == mode, "\(name) cycle \(cycle): preferred mode preserved after close")
            assertCondition(closedSnapshot.cameraState == .showingSuggestions, "\(name) cycle \(cycle): returned to suggestions after close")
        }
    }

    @MainActor
    private func attachOverlay(to view: UIView) {
        guard statusView.superview == nil else { return }

        statusView.isEditable = false
        statusView.isSelectable = false
        statusView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        statusView.textColor = .white
        statusView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusView.layer.cornerRadius = 10
        statusView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        statusView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            statusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusView.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    @MainActor
    private func assertGuidanceVisible(name: String, mode: LMARGuidanceButtonState, snapshot: LMARGuidanceRuntimeSnapshot) {
        switch mode {
        case .box:
            assertCondition(!snapshot.referenceBoxHidden, "\(name): reference box visible")
            assertCondition(snapshot.lineArtHidden, "\(name): lineArt hidden in box mode")
        case .lineArt:
            assertCondition(snapshot.referenceBoxHidden, "\(name): reference box hidden in lineArt mode")
            assertCondition(!snapshot.lineArtHidden, "\(name): lineArt visible")
        case .off, .unavailable:
            assertCondition(false, "\(name): unsupported mode \(mode.logName)")
        }
    }

    @MainActor
    private func assertGuidanceHidden(name: String, mode: LMARGuidanceButtonState, snapshot: LMARGuidanceRuntimeSnapshot) {
        switch mode {
        case .box:
            assertCondition(snapshot.referenceBoxHidden, "\(name): reference box hidden")
        case .lineArt:
            assertCondition(snapshot.lineArtHidden, "\(name): lineArt hidden")
        case .off, .unavailable:
            assertCondition(false, "\(name): unsupported mode \(mode.logName)")
        }
    }

    @MainActor
    private func assertReferenceAngle(name: String, actual: CGFloat, expected: CGFloat) {
        let delta = normalizedAngle(actual - expected)
        assertCondition(abs(delta) < 0.12, "\(name): angle=\(String(format: "%.2f", actual)) expected=\(String(format: "%.2f", expected))")
    }

    @MainActor
    private func assertGuidanceAngle(name: String, actual: CGFloat, expected: CGFloat) {
        let delta = normalizedAngle(actual - expected)
        assertCondition(abs(delta) < 0.12, "\(name): angle=\(String(format: "%.2f", actual)) expected=\(String(format: "%.2f", expected))")
    }

    @MainActor
    private func assertCondition(_ condition: Bool, _ message: String) {
        if condition {
            log("PASS \(message)")
        } else {
            failures.append(message)
            log("FAIL \(message)")
        }
    }

    @MainActor
    private func log(_ message: String) {
        let line = "[ARGuidanceHarness] \(message)"
        eventLog.append(line)
        if eventLog.count > 18 {
            eventLog.removeFirst(eventLog.count - 18)
        }
        statusView.text = eventLog.joined(separator: "\n")
        print(line)
    }

    private func makeSuggestion(id: String, image: UIImage) -> LMCompositionSuggestion {
        LMCompositionSuggestion(
            id: id,
            sceneType: "debug",
            source: "debug",
            ready: true,
            imageUrl: nil,
            width: Int(image.size.width),
            height: Int(image.size.height),
            rank: 1,
            score: 1
        )
    }

    private func makeReferenceImage(size: CGSize, tint: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let frame = CGRect(
                x: size.width * 0.2,
                y: size.height * 0.12,
                width: size.width * 0.5,
                height: size.height * 0.68
            )
            tint.setStroke()
            let path = UIBezierPath(roundedRect: frame, cornerRadius: 24)
            path.lineWidth = 10
            path.stroke()

            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(
                x: frame.midX - 42,
                y: frame.minY + 28,
                width: 84,
                height: 84
            )).fill()
            UIBezierPath(
                roundedRect: CGRect(
                    x: frame.midX - 70,
                    y: frame.minY + 128,
                    width: 140,
                    height: frame.height - 170
                ),
                cornerRadius: 32
            ).fill()
        }
    }

    private func makeLineArtImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let stroke = UIBezierPath()
            stroke.move(to: CGPoint(x: size.width * 0.32, y: size.height * 0.18))
            stroke.addCurve(
                to: CGPoint(x: size.width * 0.68, y: size.height * 0.18),
                controlPoint1: CGPoint(x: size.width * 0.4, y: size.height * 0.08),
                controlPoint2: CGPoint(x: size.width * 0.6, y: size.height * 0.08)
            )
            stroke.addCurve(
                to: CGPoint(x: size.width * 0.68, y: size.height * 0.78),
                controlPoint1: CGPoint(x: size.width * 0.78, y: size.height * 0.32),
                controlPoint2: CGPoint(x: size.width * 0.78, y: size.height * 0.64)
            )
            stroke.addLine(to: CGPoint(x: size.width * 0.32, y: size.height * 0.78))
            stroke.addCurve(
                to: CGPoint(x: size.width * 0.32, y: size.height * 0.18),
                controlPoint1: CGPoint(x: size.width * 0.22, y: size.height * 0.64),
                controlPoint2: CGPoint(x: size.width * 0.22, y: size.height * 0.32)
            )
            stroke.lineWidth = 6
            UIColor.white.setStroke()
            stroke.stroke()
        }
    }

    private func expectedReferenceAngle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 0
        case .landscapeLeft:
            return .pi / 2
        case .portraitUpsideDown:
            return .pi
        case .landscapeRight:
            return -.pi / 2
        default:
            return 0
        }
    }

    private func expectedGuidanceAngle(referenceImage: UIImage, orientation: UIDeviceOrientation) -> CGFloat {
        let isLandscapeReference = referenceImage.size.width > referenceImage.size.height

        if isLandscapeReference {
            switch orientation {
            case .landscapeLeft:
                return 0
            case .landscapeRight:
                return -.pi
            default:
                return 0
            }
        }

        switch orientation {
        case .portrait:
            return 0
        case .portraitUpsideDown:
            return .pi
        default:
            return 0
        }
    }

    private func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle
        while normalized > .pi { normalized -= (.pi * 2) }
        while normalized < -.pi { normalized += (.pi * 2) }
        return normalized
    }

    @MainActor
    private func wait(seconds: TimeInterval) async {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
#endif
