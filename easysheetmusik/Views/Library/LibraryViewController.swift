import UIKit
import UniformTypeIdentifiers
import PhotosUI

private enum LibraryLayoutMode {
    case grid
    case list

    var symbolName: String {
        switch self {
        case .grid: "rectangle.grid.2x2"
        case .list: "list.bullet.rectangle"
        }
    }
}

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
    private let dashboardView = LibraryDashboardView()
    private var dashboardHeightConstraint: NSLayoutConstraint?
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private let searchController = UISearchController(searchResultsController: nil)
    private var layoutMode: LibraryLayoutMode = .grid

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
        title = T("我的曲库", "My Library")
        view.backgroundColor = ChordPressTheme.Color.surface
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
            ),
            UIBarButtonItem(
                image: UIImage(systemName: layoutMode.symbolName),
                style: .plain,
                target: self,
                action: #selector(toggleLayoutMode)
            )
        ]
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(
            title: T("全部乐谱", "All Scores"),
            image: UIImage(systemName: "folder"),
            primaryAction: nil,
            menu: makeFolderMenu()
            ),
            UIBarButtonItem(
                title: T("标签", "Tags"),
                image: UIImage(systemName: "tag"),
                primaryAction: nil,
                menu: makeTagMenu()
            )
        ]
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = T("搜索曲名或作者", "Search title or artist")
        searchController.searchBar.searchTextField.backgroundColor = ChordPressTheme.Color.canvas
        searchController.searchBar.searchTextField.textColor = ChordPressTheme.Color.charcoal
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        configureDashboard()
        configureCollectionView()
        configureEmptyState()
        viewModel.onChange = { [weak self] in self?.reloadContent() }
        reloadContent()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { [weak self] _ in
            self?.collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    private func configureDashboard() {
        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        dashboardView.importButton.addTarget(self, action: #selector(showImportMenu), for: .touchUpInside)
        dashboardView.setlistsButton.addTarget(self, action: #selector(showSetlists), for: .touchUpInside)
        view.addSubview(dashboardView)
        let height = dashboardView.heightAnchor.constraint(
            equalToConstant: traitCollection.horizontalSizeClass == .regular ? 138 : 0
        )
        dashboardHeightConstraint = height
        dashboardView.isHidden = traitCollection.horizontalSizeClass != .regular
        NSLayoutConstraint.activate([
            dashboardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            dashboardView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            dashboardView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            height
        ])
    }

    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ScoreCell.self, forCellWithReuseIdentifier: ScoreCell.reuseIdentifier)
        collectionView.register(ScoreListCell.self, forCellWithReuseIdentifier: ScoreListCell.reuseIdentifier)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: dashboardView.bottomAnchor, constant: 8),
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
        dashboardView.configure(
            scoreCount: viewModel.scores.count,
            folderCount: viewModel.folders.count,
            selectedFolder: viewModel.selectedFolderTitle
        )
        navigationItem.leftBarButtonItems?.first?.title = viewModel.selectedFolderTitle
        navigationItem.leftBarButtonItems?.first?.menu = makeFolderMenu()
        navigationItem.leftBarButtonItems?.last?.title = viewModel.selectedTag ?? T("标签", "Tags")
        navigationItem.leftBarButtonItems?.last?.menu = makeTagMenu()
        let hasScores = !viewModel.scores.isEmpty
        emptyStateView.isHidden = hasScores
        collectionView.isHidden = !hasScores
    }

    private func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        let horizontalInset: CGFloat = traitCollection.horizontalSizeClass == .regular ? 28 : 16
        layout.sectionInset = UIEdgeInsets(top: 12, left: horizontalInset, bottom: 32, right: horizontalInset)
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 24
        return layout
    }

    private func makeFolderMenu() -> UIMenu {
        var children: [UIMenuElement] = [
            UIAction(
                title: T("全部乐谱", "All Scores"),
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
        children.append(UIAction(title: T("新建文件夹", "New Folder"), image: UIImage(systemName: "folder.badge.plus")) {
            [weak self] _ in self?.promptForFolder()
        })
        return UIMenu(title: T("文件夹", "Folders"), children: children)
    }

    private func makeTagMenu() -> UIMenu {
        var children: [UIMenuElement] = [
            UIAction(
                title: T("全部标签", "All Tags"),
                image: UIImage(systemName: "tag"),
                state: viewModel.selectedTag == nil ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectTag(nil)
            }
        ]
        children += viewModel.tags.map { tag in
            UIAction(
                title: tag,
                image: UIImage(systemName: "tag.fill"),
                state: viewModel.selectedTag == tag ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectTag(tag)
            }
        }
        return UIMenu(title: T("标签", "Tags"), children: children)
    }

    @objc private func toggleLayoutMode() {
        layoutMode = layoutMode == .grid ? .list : .grid
        navigationItem.rightBarButtonItems?.last?.image = UIImage(systemName: layoutMode.symbolName)
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }

    private func promptForFolder() {
        let alert = UIAlertController(title: T("新建文件夹", "New Folder"), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = T("文件夹名称", "Folder name") }
        alert.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: T("创建", "Create"), style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text else { return }
            self?.viewModel.createFolder(named: name)
        })
        present(alert, animated: true)
    }

    @objc private func showImportMenu() {
        let sheet = UIAlertController(title: T("导入乐谱", "Import Score"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: T("从文件导入", "Import from Files"), style: .default) { [weak self] _ in
            self?.presentDocumentPicker()
        })
        sheet.addAction(UIAlertAction(title: T("从照片导入", "Import from Photos"), style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: T("拍照导入", "Import from Camera"), style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }
        sheet.addAction(UIAlertAction(title: T("新建 ChordPro", "New ChordPro"), style: .default) { [weak self] _ in
            guard let self else { return }
            self.delegate?.libraryViewControllerDidRequestNewChordPro(self)
        })
        sheet.addAction(UIAlertAction(title: T("粘贴 ChordPro 文本", "Paste ChordPro Text"), style: .default) { [weak self] _ in
            self?.pasteChordPro()
        })
        sheet.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
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
            showMessage(
                title: T("剪贴板为空", "Clipboard Empty"),
                message: T("请先复制 ChordPro 或带和弦的文本。", "Copy ChordPro text or chorded lyrics first.")
            )
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
            title: T("导入失败", "Import Failed"),
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: T("好", "OK"), style: .default))
        present(alert, animated: true)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: T("好", "OK"), style: .default))
        present(alert, animated: true)
    }
}

extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.visibleScores.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if layoutMode == .list {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ScoreListCell.reuseIdentifier,
                for: indexPath
            ) as? ScoreListCell else { return UICollectionViewCell() }
            cell.configure(with: viewModel.visibleScores[indexPath.item])
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ScoreCell.reuseIdentifier,
                for: indexPath
            ) as? ScoreCell else { return UICollectionViewCell() }
            cell.configure(with: viewModel.visibleScores[indexPath.item])
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.libraryViewController(self, didSelect: viewModel.visibleScores[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if layoutMode == .list {
            let horizontalInset: CGFloat = traitCollection.horizontalSizeClass == .regular ? 56 : 32
            return CGSize(width: collectionView.bounds.width - horizontalInset, height: 132)
        }
        let availableWidth = collectionView.bounds.width
        let columns: CGFloat
        if traitCollection.horizontalSizeClass == .regular {
            columns = max(3, floor((availableWidth - 56) / 240))
        } else {
            columns = 2
        }
        let inset: CGFloat = traitCollection.horizontalSizeClass == .regular ? 56 : 32
        let spacing = CGFloat(columns - 1) * (traitCollection.horizontalSizeClass == .regular ? 20 : 12)
        let totalSpacing = spacing + inset
        let width = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: width, height: width * 1.28)
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
                actions.append(UIAction(title: T("编辑", "Edit"), image: UIImage(systemName: "pencil")) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.libraryViewController(self, didRequestEdit: score)
                })
            }
            actions.append(UIAction(title: T("编辑标签", "Edit Tags"), image: UIImage(systemName: "tag")) {
                [weak self] _ in self?.promptForTags(score)
            })
            let moveActions = [
                UIAction(
                    title: T("未分类", "Uncategorized"),
                    state: score.folder == nil ? .on : .off
                ) { [weak self] _ in
                    self?.move(score, to: nil)
                }
            ] + self.viewModel.folders.map { folder in
                UIAction(
                    title: folder,
                    state: score.folder == folder ? .on : .off
                ) { [weak self] _ in
                    self?.move(score, to: folder)
                }
            }
            actions.append(UIAction(title: T("移动到新文件夹", "Move to New Folder"), image: UIImage(systemName: "folder.badge.plus")) {
                [weak self] _ in self?.promptToMove(score)
            })
            actions.append(UIAction(
                title: T("删除", "Delete"),
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
            return UIMenu(children: [UIMenu(title: T("移动到文件夹", "Move to Folder"), children: moveActions)] + actions)
        }
    }

    private func promptToMove(_ score: MusicScore) {
        let alert = UIAlertController(title: T("移动到新文件夹", "Move to New Folder"), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = T("文件夹名称", "Folder name") }
        alert.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: T("移动", "Move"), style: .default) { [weak self, weak alert] _ in
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

    private func promptForTags(_ score: MusicScore) {
        let alert = UIAlertController(
            title: T("编辑标签", "Edit Tags"),
            message: T("用逗号分隔多个标签", "Separate multiple tags with commas"),
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = T("例如：本周, 吉他", "e.g. This Week, Guitar")
            field.text = score.tags.joined(separator: ", ")
        }
        alert.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: T("保存", "Save"), style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text else { return }
            let tags = text
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            do {
                try self.viewModel.updateTags(for: score, tags: tags)
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

    private func move(_ score: MusicScore, to folder: String?) {
        do {
            try viewModel.moveScore(score, to: folder)
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
                            try self.viewModel.importImage(
                                image,
                                title: T("照片乐谱 \(index + 1)", "Photo Score \(index + 1)")
                            )
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
            try viewModel.importImage(image, title: T("拍照乐谱", "Camera Score"))
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
        icon.tintColor = ChordPressTheme.Color.primary

        let title = UILabel()
        title.text = T("开始建立你的曲库", "Start building your library")
        title.font = .preferredFont(forTextStyle: .title2)
        title.textColor = ChordPressTheme.Color.charcoal
        title.textAlignment = .center

        let detail = UILabel()
        detail.text = T("导入 PDF、图片或 ChordPro 和弦谱", "Import PDFs, images, or ChordPro charts")
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = ChordPressTheme.Color.slate
        detail.textAlignment = .center

        addButton.configuration = ChordPressTheme.primaryButton(
            title: T("导入乐谱", "Import Score"),
            image: "square.and.arrow.down"
        )

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
    private let previewImageView = UIImageView()
    private let previewTextView = UITextView()
    private let iconView = UIImageView()
    private let formatLabel = UILabel()
    private let titleLabel = UILabel()
    private let metadataLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = ChordPressTheme.Color.canvas
        contentView.layer.cornerRadius = ChordPressTheme.Radius.card
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = ChordPressTheme.Color.hairline.cgColor
        contentView.clipsToBounds = true
        layer.shadowColor = ChordPressTheme.Color.ink.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.masksToBounds = false

        coverView.backgroundColor = ChordPressTheme.Color.gray
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewTextView.isEditable = false
        previewTextView.isScrollEnabled = false
        previewTextView.isUserInteractionEnabled = false
        previewTextView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 8, right: 12)
        previewTextView.backgroundColor = ChordPressTheme.Color.surfaceSoft
        iconView.tintColor = ChordPressTheme.Color.primary
        iconView.contentMode = .scaleAspectFit
        formatLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        formatLabel.textColor = ChordPressTheme.Color.primaryDeep
        formatLabel.backgroundColor = ChordPressTheme.Color.lavender
        formatLabel.textAlignment = .center
        formatLabel.layer.cornerRadius = ChordPressTheme.Radius.badge
        formatLabel.clipsToBounds = true
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ChordPressTheme.Color.charcoal
        titleLabel.numberOfLines = 2
        metadataLabel.font = .preferredFont(forTextStyle: .caption1)
        metadataLabel.textColor = ChordPressTheme.Color.steel

        [coverView, previewImageView, previewTextView, iconView, formatLabel, titleLabel, metadataLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.78),
            previewImageView.topAnchor.constraint(equalTo: coverView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),
            previewTextView.topAnchor.constraint(equalTo: coverView.topAnchor),
            previewTextView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            previewTextView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            previewTextView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),
            iconView.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            formatLabel.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 12),
            formatLabel.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -12),
            formatLabel.heightAnchor.constraint(equalToConstant: 24),
            formatLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 12),
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
        metadataLabel.text = [score.artist, score.folder, score.tags.joined(separator: " #"), T("\(score.pages.count) 页", "\(score.pages.count) pages")]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        iconView.image = UIImage(systemName: score.sourceFormat.symbolName)
        formatLabel.text = "  \(score.sourceFormat.displayName)  "
        coverView.backgroundColor = tint(for: score.sourceFormat)
        iconView.tintColor = foreground(for: score.sourceFormat)
        formatLabel.textColor = foreground(for: score.sourceFormat)
        formatLabel.backgroundColor = tint(for: score.sourceFormat).withAlphaComponent(0.9)
        previewImageView.isHidden = true
        previewTextView.isHidden = true
        iconView.isHidden = true

        switch score.pages.first?.content {
        case .image(let image):
            previewImageView.image = image
            previewImageView.isHidden = false
        case .attributedText(let text):
            let preview = NSMutableAttributedString(attributedString: text)
            preview.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 9),
                range: NSRange(location: 0, length: preview.length)
            )
            previewTextView.attributedText = preview
            previewTextView.isHidden = false
        case nil:
            iconView.isHidden = false
        }
    }

    private func tint(for format: SourceFormat) -> UIColor {
        switch format {
        case .pdf: return ChordPressTheme.Color.peach
        case .image: return ChordPressTheme.Color.sky
        case .chordPro: return ChordPressTheme.Color.lavender
        case .musicXML: return ChordPressTheme.Color.mint
        case .tab: return ChordPressTheme.Color.cream
        }
    }

    private func foreground(for format: SourceFormat) -> UIColor {
        switch format {
        case .pdf: return ChordPressTheme.Color.orange
        case .image: return ChordPressTheme.Color.linkBlue
        case .chordPro: return ChordPressTheme.Color.primaryDeep
        case .musicXML: return ChordPressTheme.Color.teal
        case .tab: return ChordPressTheme.Color.charcoal
        }
    }
}

private final class ScoreListCell: UICollectionViewCell {
    static let reuseIdentifier = "ScoreListCell"

    private let coverView = UIView()
    private let previewImageView = UIImageView()
    private let previewTextView = UITextView()
    private let iconView = UIImageView()
    private let formatLabel = UILabel()
    private let titleLabel = UILabel()
    private let metadataLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = ChordPressTheme.Color.canvas
        contentView.layer.cornerRadius = ChordPressTheme.Radius.card
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = ChordPressTheme.Color.hairline.cgColor
        contentView.clipsToBounds = true
        layer.shadowColor = ChordPressTheme.Color.ink.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.masksToBounds = false

        coverView.backgroundColor = ChordPressTheme.Color.gray
        coverView.layer.cornerRadius = 10
        coverView.layer.cornerCurve = .continuous
        coverView.clipsToBounds = true
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewTextView.isEditable = false
        previewTextView.isScrollEnabled = false
        previewTextView.isUserInteractionEnabled = false
        previewTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 4, right: 8)
        previewTextView.backgroundColor = ChordPressTheme.Color.surfaceSoft
        iconView.contentMode = .scaleAspectFit
        formatLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        formatLabel.textAlignment = .center
        formatLabel.layer.cornerRadius = ChordPressTheme.Radius.badge
        formatLabel.clipsToBounds = true
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = ChordPressTheme.Color.charcoal
        titleLabel.numberOfLines = 2
        metadataLabel.font = .preferredFont(forTextStyle: .subheadline)
        metadataLabel.textColor = ChordPressTheme.Color.steel
        metadataLabel.numberOfLines = 2

        [coverView, previewImageView, previewTextView, iconView, formatLabel, titleLabel, metadataLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        contentView.addSubview(coverView)
        [previewImageView, previewTextView, iconView].forEach(coverView.addSubview)
        [formatLabel, titleLabel, metadataLabel].forEach(contentView.addSubview)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            coverView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            coverView.widthAnchor.constraint(equalToConstant: 92),
            previewImageView.topAnchor.constraint(equalTo: coverView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),
            previewTextView.topAnchor.constraint(equalTo: coverView.topAnchor),
            previewTextView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            previewTextView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            previewTextView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),
            iconView.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),
            formatLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            formatLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            formatLabel.heightAnchor.constraint(equalToConstant: 24),
            formatLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: formatLabel.leadingAnchor, constant: -12),
            metadataLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metadataLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            metadataLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with score: MusicScore) {
        titleLabel.text = score.title
        metadataLabel.text = [score.artist, score.folder, score.tags.joined(separator: " #"), T("\(score.pages.count) 页", "\(score.pages.count) pages")]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        iconView.image = UIImage(systemName: score.sourceFormat.symbolName)
        formatLabel.text = "  \(score.sourceFormat.displayName)  "
        coverView.backgroundColor = tint(for: score.sourceFormat)
        iconView.tintColor = foreground(for: score.sourceFormat)
        formatLabel.textColor = foreground(for: score.sourceFormat)
        formatLabel.backgroundColor = tint(for: score.sourceFormat).withAlphaComponent(0.9)
        previewImageView.isHidden = true
        previewTextView.isHidden = true
        iconView.isHidden = true

        switch score.pages.first?.content {
        case .image(let image):
            previewImageView.image = image
            previewImageView.isHidden = false
        case .attributedText(let text):
            let preview = NSMutableAttributedString(attributedString: text)
            preview.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 7),
                range: NSRange(location: 0, length: preview.length)
            )
            previewTextView.attributedText = preview
            previewTextView.isHidden = false
        case nil:
            iconView.isHidden = false
        }
    }

    private func tint(for format: SourceFormat) -> UIColor {
        switch format {
        case .pdf: return ChordPressTheme.Color.peach
        case .image: return ChordPressTheme.Color.sky
        case .chordPro: return ChordPressTheme.Color.lavender
        case .musicXML: return ChordPressTheme.Color.mint
        case .tab: return ChordPressTheme.Color.cream
        }
    }

    private func foreground(for format: SourceFormat) -> UIColor {
        switch format {
        case .pdf: return ChordPressTheme.Color.orange
        case .image: return ChordPressTheme.Color.linkBlue
        case .chordPro: return ChordPressTheme.Color.primaryDeep
        case .musicXML: return ChordPressTheme.Color.teal
        case .tab: return ChordPressTheme.Color.charcoal
        }
    }
}

private final class LibraryDashboardView: UIView {
    let importButton = UIButton(type: .system)
    let setlistsButton = UIButton(type: .system)

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChordPressTheme.Color.brandNavy
        layer.cornerRadius = ChordPressTheme.Radius.card
        layer.cornerCurve = .continuous

        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.text = T("准备好下一次演奏", "Ready for your next performance")
        titleLabel.textColor = ChordPressTheme.Color.onDark
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.textColor = ChordPressTheme.Color.onDarkMuted

        importButton.configuration = ChordPressTheme.primaryButton(
            title: T("导入乐谱", "Import Score"),
            image: "square.and.arrow.down"
        )
        setlistsButton.configuration = ChordPressTheme.secondaryOnDarkButton(
            title: T("演出歌单", "Setlists"),
            image: "music.note.list"
        )

        addDecorativeDots()

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 6

        let actions = UIStackView(arrangedSubviews: [importButton, setlistsButton])
        actions.spacing = 12
        actions.distribution = .fillEqually

        let root = UIStackView(arrangedSubviews: [textStack, actions])
        root.axis = .horizontal
        root.alignment = .center
        root.spacing = 24
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            actions.widthAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(scoreCount: Int, folderCount: Int, selectedFolder: String) {
        detailLabel.text = T(
            "\(selectedFolder) · \(scoreCount) 首乐谱 · \(folderCount) 个文件夹",
            "\(selectedFolder) · \(scoreCount) scores · \(folderCount) folders"
        )
    }

    private func addDecorativeDots() {
        let dots = [
            (ChordPressTheme.Color.yellow, 44, 28, CGFloat(10)),
            (ChordPressTheme.Color.pink, 620, 26, CGFloat(8)),
            (ChordPressTheme.Color.purpleSoft, 760, 92, CGFloat(12))
        ]
        dots.forEach { color, leading, top, size in
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = color
            dot.layer.cornerRadius = size / 2
            dot.alpha = 0.9
            addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: size),
                dot.heightAnchor.constraint(equalToConstant: size),
                dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: CGFloat(leading)),
                dot.topAnchor.constraint(equalTo: topAnchor, constant: CGFloat(top))
            ])
        }
    }
}
