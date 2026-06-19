import UIKit
import UniformTypeIdentifiers
import PhotosUI

protocol LibraryViewControllerDelegate: AnyObject {
    func libraryViewController(_ viewController: LibraryViewController, didSelect score: MusicScore)
    func libraryViewControllerDidRequestNewChordPro(_ viewController: LibraryViewController)
    func libraryViewController(_ viewController: LibraryViewController, didRequestEdit score: MusicScore)
    func libraryViewControllerDidRequestSetlists(_ viewController: LibraryViewController)
}

final class LibraryViewController: UIViewController {
    weak var delegate: LibraryViewControllerDelegate?

    private let viewModel: LibraryViewModel
    private let emptyStateView = LibraryEmptyStateView()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private let searchController = UISearchController(searchResultsController: nil)

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的曲库"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain,
                target: self,
                action: #selector(showImportMenu)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "music.note.list"),
                style: .plain,
                target: self,
                action: #selector(showSetlists)
            )
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "全部乐谱",
            image: UIImage(systemName: "folder"),
            primaryAction: nil,
            menu: makeFolderMenu()
        )
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜索曲名或作者"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        configureCollectionView()
        configureEmptyState()
        viewModel.onChange = { [weak self] in self?.reloadContent() }
        reloadContent()
    }

    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ScoreCell.self, forCellWithReuseIdentifier: ScoreCell.reuseIdentifier)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addButton.addTarget(self, action: #selector(showImportMenu), for: .touchUpInside)
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func reloadContent() {
        collectionView.reloadData()
        navigationItem.leftBarButtonItem?.title = viewModel.selectedFolderTitle
        navigationItem.leftBarButtonItem?.menu = makeFolderMenu()
        let hasScores = !viewModel.scores.isEmpty
        emptyStateView.isHidden = hasScores
        collectionView.isHidden = !hasScores
    }

    private func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 20, left: 16, bottom: 24, right: 16)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        return layout
    }

    private func makeFolderMenu() -> UIMenu {
        var children: [UIMenuElement] = [
            UIAction(
                title: "全部乐谱",
                image: UIImage(systemName: "tray.full"),
                state: viewModel.selectedFolder == nil ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectFolder(nil)
            }
        ]
        children += viewModel.folders.map { folder in
            UIAction(
                title: folder,
                image: UIImage(systemName: "folder"),
                state: viewModel.selectedFolder == folder ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectFolder(folder)
            }
        }
        children.append(UIAction(title: "新建文件夹", image: UIImage(systemName: "folder.badge.plus")) {
            [weak self] _ in self?.promptForFolder()
        })
        return UIMenu(title: "文件夹", children: children)
    }

    private func promptForFolder() {
        let alert = UIAlertController(title: "新建文件夹", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "文件夹名称" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "创建", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text else { return }
            self?.viewModel.createFolder(named: name)
        })
        present(alert, animated: true)
    }

    @objc private func showImportMenu() {
        let sheet = UIAlertController(title: "导入乐谱", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "从文件导入", style: .default) { [weak self] _ in
            self?.presentDocumentPicker()
        })
        sheet.addAction(UIAlertAction(title: "从照片导入", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "拍照导入", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }
        sheet.addAction(UIAlertAction(title: "新建 ChordPro", style: .default) { [weak self] _ in
            guard let self else { return }
            self.delegate?.libraryViewControllerDidRequestNewChordPro(self)
        })
        sheet.addAction(UIAlertAction(title: "粘贴 ChordPro 文本", style: .default) { [weak self] _ in
            self?.pasteChordPro()
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(sheet, animated: true)
    }

    @objc private func showSetlists() {
        delegate?.libraryViewControllerDidRequestSetlists(self)
    }

    private func presentDocumentPicker() {
        var contentTypes: [UTType] = [.pdf, .image, .plainText, .xml]
        if let chordPro = UTType(filenameExtension: "cho") {
            contentTypes.append(chordPro)
        }
        if let musicXML = UTType(filenameExtension: "musicxml") {
            contentTypes.append(musicXML)
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pasteChordPro() {
        guard let text = UIPasteboard.general.string,
              text.contains(where: { !$0.isWhitespace }) else {
            showMessage(title: "剪贴板为空", message: "请先复制 ChordPro 或带和弦的文本。")
            return
        }
        do {
            _ = try viewModel.saveChordPro(text: text)
        } catch {
            show(error: error)
        }
    }

    private func show(error: Error) {
        let alert = UIAlertController(
            title: "导入失败",
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.visibleScores.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ScoreCell.reuseIdentifier,
            for: indexPath
        ) as! ScoreCell
        cell.configure(with: viewModel.visibleScores[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.libraryViewController(self, didSelect: viewModel.visibleScores[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = traitCollection.horizontalSizeClass == .regular ? 4 : 2
        let totalSpacing = CGFloat(columns - 1) * 12 + 32
        let width = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: width, height: width * 1.22)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let score = viewModel.visibleScores[indexPath.item]
        return UIContextMenuConfiguration(identifier: score.id.uuidString as NSString, previewProvider: nil) { _ in
            var actions: [UIAction] = []
            if score.sourceFormat == .chordPro {
                actions.append(UIAction(title: "编辑", image: UIImage(systemName: "pencil")) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.libraryViewController(self, didRequestEdit: score)
                })
            }
            let moveActions = [
                UIAction(
                    title: "未分类",
                    state: score.folder == nil ? .on : .off
                ) { [weak self] _ in
                    try? self?.viewModel.moveScore(score, to: nil)
                }
            ] + self.viewModel.folders.map { folder in
                UIAction(
                    title: folder,
                    state: score.folder == folder ? .on : .off
                ) { [weak self] _ in
                    try? self?.viewModel.moveScore(score, to: folder)
                }
            }
            actions.append(UIAction(title: "移动到新文件夹", image: UIImage(systemName: "folder.badge.plus")) {
                [weak self] _ in self?.promptToMove(score)
            })
            actions.append(UIAction(
                title: "删除",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                guard let self else { return }
                do {
                    try self.viewModel.deleteScore(at: indexPath.item)
                } catch {
                    self.show(error: error)
                }
            })
            return UIMenu(children: [UIMenu(title: "移动到文件夹", children: moveActions)] + actions)
        }
    }

    private func promptToMove(_ score: MusicScore) {
        let alert = UIAlertController(title: "移动到新文件夹", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "文件夹名称" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "移动", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            do {
                try self.viewModel.moveScore(score, to: name)
            } catch {
                self.show(error: error)
            }
        })
        present(alert, animated: true)
    }
}

extension LibraryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            try viewModel.importScore(from: url)
        } catch {
            show(error: error)
        }
    }
}

extension LibraryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.setSearchText(searchController.searchBar.text ?? "")
    }
}

extension LibraryViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for (index, result) in results.enumerated() {
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let error {
                        self.show(error: error)
                    } else if let image = object as? UIImage {
                        do {
                            try self.viewModel.importImage(image, title: "照片乐谱 \(index + 1)")
                        } catch {
                            self.show(error: error)
                        }
                    }
                }
            }
        }
    }
}

extension LibraryViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        do {
            try viewModel.importImage(image, title: "拍照乐谱")
        } catch {
            show(error: error)
        }
    }
}

private final class LibraryEmptyStateView: UIView {
    let addButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        let icon = UIImageView(image: UIImage(systemName: "music.note.house"))
        icon.preferredSymbolConfiguration = .init(pointSize: 46, weight: .light)
        icon.tintColor = .secondaryLabel

        let title = UILabel()
        title.text = "开始建立你的曲库"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textAlignment = .center

        let detail = UILabel()
        detail.text = "导入 PDF、图片或 ChordPro 和弦谱"
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = .secondaryLabel
        detail.textAlignment = .center

        var configuration = UIButton.Configuration.filled()
        configuration.title = "导入乐谱"
        configuration.image = UIImage(systemName: "square.and.arrow.down")
        configuration.imagePadding = 8
        configuration.cornerStyle = .large
        addButton.configuration = configuration

        let stack = UIStackView(arrangedSubviews: [icon, title, detail, addButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(24, after: detail)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ScoreCell: UICollectionViewCell {
    static let reuseIdentifier = "ScoreCell"

    private let coverView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let metadataLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        coverView.backgroundColor = .tertiarySystemFill
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 2
        metadataLabel.font = .preferredFont(forTextStyle: .caption1)
        metadataLabel.textColor = .secondaryLabel

        [coverView, iconView, titleLabel, metadataLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.7),
            iconView.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),
            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            metadataLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metadataLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metadataLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with score: MusicScore) {
        titleLabel.text = score.title
        metadataLabel.text = "\(score.sourceFormat.rawValue) · \(score.pages.count) 页"
        iconView.image = UIImage(systemName: score.sourceFormat.symbolName)
    }
}
