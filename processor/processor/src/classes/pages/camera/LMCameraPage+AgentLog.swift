//
//  LMCameraPage+AgentLog.swift
//  processor
//

import UIKit

extension LMCameraPage {

    /// Installs the composition-mode "Log" entry point for the agent request log.
    func setupAgentLogButtonIfNeeded() {
        guard agentLogButton == nil else { return }

        let button = UIButton(type: .system)
        button.setTitle("Log", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.addTarget(self, action: #selector(handleAgentLogTapped), for: .touchUpInside)
        topStatusBarView.addSubview(button)
        button.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        agentLogButton = button
        updateAgentLogButtonVisibility()
    }

    func updateAgentLogButtonVisibility() {
        agentLogButton?.isHidden = currentCameraState != .compositionSelected
    }

    @objc private func handleAgentLogTapped() {
        /// Pause live scoring while Log covers the camera — avoids ANE/main-thread contention.
        agentCoachingController.setPaused(true)
        let page = LMAgentRequestLogPage()
        page.onCaptureLive = { [weak self] in
            self?.captureAgentLogLiveFrame() ?? false
        }
        page.onDismissed = { [weak self] in
            self?.agentCoachingController.setPaused(false)
        }
        page.modalPresentationStyle = .fullScreen
        present(page, animated: true)
    }

    /// Captures the current preview/reference pair for the request log without running Instruct.
    @discardableResult
    func captureAgentLogLiveFrame() -> Bool {
        guard let reference = currentReferenceImage,
              let cameraView = capturePreviewFrameForScoring() else {
            return false
        }
        let config = LMConfigRepository.shared.get()
        let orientation = LMDeviceOrientationManager.shared.currentOrientation
        LMAgentRequestLogRecorder.recordLiveCapture(
            orientation: orientation,
            reference: reference,
            cameraView: cameraView,
            config: config,
            userPrompt: "(live capture — no LLM round)"
        )
        return true
    }
}
