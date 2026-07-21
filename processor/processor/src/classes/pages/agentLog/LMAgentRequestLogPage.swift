//
//  LMAgentRequestLogPage.swift
//  processor
//

import UIKit
import SnapKit

/// Full-screen agent request log for orientation and payload validation.
final class LMAgentRequestLogPage: LMPageWrapper {
    var onCaptureLive: (() -> Bool)?
    /// Called once when the page is dismissed (resumes camera score loop).
    var onDismissed: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var storeObserver: NSObjectProtocol?
    private weak var liveScoreSection: UIView?
    private var didNotifyDismissed = false

    private enum ViewTag {
        static let liveScoreSection = 91001
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        setupLayout()
        reloadContent()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .agentRequestLogStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleStoreChange(notification)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        LMAgentRequestLogStore.shared.setLogPageVisible(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            notifyDismissedIfNeeded()
        }
    }

    deinit {
        LMAgentRequestLogStore.shared.setLogPageVisible(false)
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    private func setupLayout() {
        viewAdapter(scrollView)
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(scrollView.snp.width).offset(-32)
        }
    }

    /**
     Handles store notifications.

     Score-only changes update the live score section in place; everything else rebuilds.
     */
    private func handleStoreChange(_ notification: Notification) {
        let raw = notification.userInfo?[LMAgentRequestLogChangeKind.userInfoKey] as? String
        let kind = raw.flatMap(LMAgentRequestLogChangeKind.init(rawValue:)) ?? .full
        switch kind {
        case .scoreOnly:
            updateLiveScoreSection()
        case .full:
            reloadContent()
        }
    }

    /// Replaces only the live score-loop section without tearing down images/buttons.
    private func updateLiveScoreSection() {
        let store = LMAgentRequestLogStore.shared
        let newSection = makeScoreSection(
            title: "当前构图分数（Score Loop）",
            score: store.latestScore
        )
        newSection.tag = ViewTag.liveScoreSection

        if let liveScoreSection,
           let index = contentStack.arrangedSubviews.firstIndex(of: liveScoreSection) {
            contentStack.removeArrangedSubview(liveScoreSection)
            liveScoreSection.removeFromSuperview()
            contentStack.insertArrangedSubview(newSection, at: index)
            self.liveScoreSection = newSection
            return
        }

        // Fallback if the section was not found (first paint race).
        reloadContent()
    }

    private func reloadContent() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        liveScoreSection = nil

        let store = LMAgentRequestLogStore.shared

        contentStack.addArrangedSubview(makeTitle("Agent request log"))
        contentStack.addArrangedSubview(makeBody(
            "Full-chain validation: Inspire Me frame, reference, camera view, scores, prompts."
        ))

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(makeButton("Back", style: .secondary) { [weak self] in
            self?.close()
        })
        buttonRow.addArrangedSubview(makeButton("Capture live", style: .primary) { [weak self] in
            guard let self else { return }
            if self.onCaptureLive?() != true {
                self.presentTextAlert(title: "Capture failed", body: "Preview or reference is not ready.")
            }
        })
        contentStack.addArrangedSubview(buttonRow)
        contentStack.addArrangedSubview(makeDivider())

        contentStack.addArrangedSubview(makeTitle("Inspire Me 取帧"))
        if let frame = store.inspireMeFrame {
            contentStack.addArrangedSubview(makeImageSection(
                title: "Raw preview frame",
                sizeLabel: frame.rawSize,
                image: frame.image,
                note: frame.orientationNote,
                onRotate: nil
            ))
        } else {
            contentStack.addArrangedSubview(makeBody("No Inspire Me frame yet."))
        }

        contentStack.addArrangedSubview(makeTitle("EVA02-Small embedding"))
        if let eva02 = store.inspireMeEva02 {
            contentStack.addArrangedSubview(makeMonoLine("vectorDim", "\(eva02.vectorDim)"))
            contentStack.addArrangedSubview(makeMonoLine("l2Norm", String(format: "%.4f", eva02.l2Norm)))
            contentStack.addArrangedSubview(makeMonoLine("vectorPreview", eva02.vectorPreview))
        } else {
            contentStack.addArrangedSubview(makeBody("No EVA02 summary yet."))
        }

        contentStack.addArrangedSubview(makeDivider())
        let liveScore = makeScoreSection(title: "当前构图分数（Score Loop）", score: store.latestScore)
        liveScore.tag = ViewTag.liveScoreSection
        liveScoreSection = liveScore
        contentStack.addArrangedSubview(liveScore)

        if let snapshot = store.snapshot, let instructScore = snapshot.compositionScore {
            let roundLabel = snapshot.round.map { "（Round \($0)）" } ?? ""
            contentStack.addArrangedSubview(makeScoreSection(
                title: "Instruct 请求时分数\(roundLabel)",
                score: instructScore
            ))
        }

        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeTitle("Agent LLM request"))

        guard let snapshot = store.snapshot else {
            contentStack.addArrangedSubview(makeBody("No agent snapshot yet. Run Instruct or tap Capture live."))
            return
        }

        contentStack.addArrangedSubview(makeBody(
            "Recorded: \(formatTime(snapshot.recordedAtMs))\n" +
            "Source: \(snapshot.source.rawValue)\n" +
            "Round: \(snapshot.round.map(String.init) ?? "-")\n" +
            "Orientation: \(snapshot.deviceOrientation)\n" +
            "Ref raw: \(snapshot.rawReferenceSize) → submitted: \(snapshot.submittedReferenceSize)\n" +
            "Cam raw: \(snapshot.rawCameraViewSize) → submitted: \(snapshot.submittedCameraViewSize)"
        ))

        contentStack.addArrangedSubview(makeImageSection(
            title: "Reference image (1st in request)",
            sizeLabel: snapshot.submittedReferenceSize,
            image: snapshot.referenceImage,
            note: nil,
            onRotate: { LMAgentRequestLogStore.shared.rotateReferenceClockwise() }
        ))
        contentStack.addArrangedSubview(makeImageSection(
            title: "Camera view (2nd in request)",
            sizeLabel: snapshot.submittedCameraViewSize,
            image: snapshot.cameraViewImage,
            note: "capturePreviewFrameForScoring() — check orientation vs reference",
            onRotate: { LMAgentRequestLogStore.shared.rotateCameraViewClockwise() }
        ))

        let promptRow = UIStackView()
        promptRow.axis = .horizontal
        promptRow.spacing = 8
        promptRow.addArrangedSubview(makeButton("View prompt", style: .secondary) { [weak self] in
            self?.presentTextAlert(
                title: "Combined prompt",
                body: "=== SYSTEM ===\n\(snapshot.systemPrompt)\n\n=== USER ===\n\(snapshot.userPrompt)"
            )
        })
        promptRow.addArrangedSubview(makeButton("View request", style: .secondary) { [weak self] in
            self?.presentTextAlert(title: "Request JSON (sanitized)", body: snapshot.requestJsonPreview)
        })
        contentStack.addArrangedSubview(promptRow)
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeTitle("Agent LLM response"))

        if let response = snapshot.llmResponse {
            contentStack.addArrangedSubview(makeBody(
                "HTTP: \(response.httpCode)" +
                (response.ttfbMs.map { " | TTFB: \($0)ms" } ?? "")
            ))
            let responseRow = UIStackView()
            responseRow.axis = .horizontal
            responseRow.spacing = 8
            responseRow.distribution = .fillEqually
            responseRow.addArrangedSubview(makeButton("Reasoning", style: .secondary) { [weak self] in
                self?.presentTextAlert(title: "Reasoning", body: response.reasoningFull)
            })
            responseRow.addArrangedSubview(makeButton("Answer", style: .secondary) { [weak self] in
                self?.presentTextAlert(title: "Answer", body: response.answerFull)
            })
            contentStack.addArrangedSubview(responseRow)
            contentStack.addArrangedSubview(makeMonoLine("extracted", response.llmActionExtracted))
            contentStack.addArrangedSubview(makeMonoLine("arbiter", response.arbiterFinalAction))
            if let error = response.errorBody, !error.isEmpty {
                contentStack.addArrangedSubview(makeMonoLine("error", error))
            }
        } else {
            contentStack.addArrangedSubview(makeBody("No LLM response recorded yet."))
        }
    }

    /// Dismisses the page and notifies the camera to resume scoring (once).
    private func close() {
        notifyDismissedIfNeeded()
        dismiss(animated: true)
    }

    private func notifyDismissedIfNeeded() {
        guard !didNotifyDismissed else { return }
        didNotifyDismissed = true
        LMAgentRequestLogStore.shared.setLogPageVisible(false)
        onDismissed?()
        onDismissed = nil
    }

    private func makeTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }

    private func makeBody(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.numberOfLines = 0
        return label
    }

    private func makeMonoLine(_ key: String, _ value: String) -> UILabel {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.numberOfLines = 0
        label.text = "\(key): \(value)"
        return label
    }

    private func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        line.snp.makeConstraints { $0.height.equalTo(1) }
        return line
    }

    private enum ButtonStyle { case primary, secondary }

    private func makeButton(_ title: String, style: ButtonStyle, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        switch style {
        case .primary:
            button.backgroundColor = UIColor.systemBlue
            button.setTitleColor(.white, for: .normal)
        case .secondary:
            button.backgroundColor = .clear
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            button.setTitleColor(.white, for: .normal)
        }
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func makeImageSection(
        title: String,
        sizeLabel: String,
        image: UIImage,
        note: String?,
        onRotate: (() -> Void)?
    ) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6

        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalSpacing

        let titleLabel = makeBody("\(title) — \(sizeLabel)")
        header.addArrangedSubview(titleLabel)
        if let onRotate {
            header.addArrangedSubview(makeButton("Rotate ↻", style: .secondary, action: onRotate))
        }
        container.addArrangedSubview(header)

        if let note {
            container.addArrangedSubview(makeBody(note))
        }

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.snp.makeConstraints { $0.height.equalTo(180) }
        container.addArrangedSubview(imageView)
        return container
    }

    private func makeScoreSection(title: String, score: LMCompositionScore?) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4
        container.addArrangedSubview(makeTitle(title))
        guard let score else {
            container.addArrangedSubview(makeBody("No score yet."))
            return container
        }
        container.addArrangedSubview(makeMonoLine("overall", String(format: "%.3f", score.overallScore)))
        container.addArrangedSubview(makeMonoLine("global", String(format: "%.3f", score.globalStructure)))
        container.addArrangedSubview(makeMonoLine("geometric", String(format: "%.3f", score.geometric)))
        if let human = score.humanScene {
            container.addArrangedSubview(makeMonoLine("humanScene", String(format: "%.3f", human)))
            if let pos = score.humanPos { container.addArrangedSubview(makeMonoLine("humanPos", String(format: "%.3f", pos))) }
            if let scale = score.humanScale { container.addArrangedSubview(makeMonoLine("humanScale", String(format: "%.3f", scale))) }
            if let depth = score.humanDepth { container.addArrangedSubview(makeMonoLine("humanDepth", String(format: "%.3f", depth))) }
        } else {
            container.addArrangedSubview(makeMonoLine("humanScene", "null"))
        }
        container.addArrangedSubview(makeMonoLine("elapsedMs", "\(score.elapsedMs)"))
        return container
    }

    private func presentTextAlert(title: String, body: String) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = body
        })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    private func formatTime(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
