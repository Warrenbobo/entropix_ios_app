//
//  LMSceneHistoryPageView.swift
//  processor
//
//  Mine → Scene History gallery (Strategy A covers).
//

import UIKit
import SnapKit

protocol LMSceneHistoryPageViewDelegate: AnyObject {
    func sceneHistoryPageViewDidSelect(_ record: LMSceneHistoryRecord, cover: UIImage?)
}

/// Grid of Scene Explore history covers.
final class LMSceneHistoryPageView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    weak var delegate: LMSceneHistoryPageViewDelegate?

    private let collectionView: UICollectionView
    private let emptyLabel = UILabel()
    private var records: [LMSceneHistoryRecord] = []

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Reloads history from disk.
    func reloadData() {
        records = LMSceneHistoryStore.loadAll()
        emptyLabel.isHidden = !records.isEmpty
        collectionView.reloadData()
    }

    func calculateContentHeight() -> CGFloat {
        guard !records.isEmpty else { return 220 }
        let rows = ceil(Double(records.count) / 2.0)
        return CGFloat(rows) * 180 + 40
    }

    func disableVerticalScrolling() {
        collectionView.isScrollEnabled = false
    }

    func showSignInPrompt() {
        // History is local — still show empty or list without login.
        reloadData()
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        records.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! LMSceneHistoryCell
        let record = records[indexPath.item]
        cell.configure(cover: LMSceneHistoryStore.loadCover(for: record), title: record.spots.first?.name)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let record = records[indexPath.item]
        delegate?.sceneHistoryPageViewDidSelect(record, cover: LMSceneHistoryStore.loadCover(for: record))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = (collectionView.bounds.width - 40) / 2
        return CGSize(width: max(140, width), height: 170)
    }
}

private extension LMSceneHistoryPageView {

    func setup() {
        backgroundColor = .clear
        addSubview(collectionView)
        addSubview(emptyLabel)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LMSceneHistoryCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }

        emptyLabel.text = LMText.profile.noSceneHistoryYet
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textAlignment = .center
        emptyLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(48)
        }
    }
}

private final class LMSceneHistoryCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor.secondarySystemFill
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(28)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(cover: UIImage?, title: String?) {
        imageView.image = cover
        titleLabel.text = "  \(title ?? "Scene")"
    }
}
