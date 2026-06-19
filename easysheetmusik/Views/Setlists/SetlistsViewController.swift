import UIKit

protocol SetlistsViewControllerDelegate: AnyObject {
    func setlistsViewController(
        _ viewController: SetlistsViewController,
        didRequestPerformance scores: [MusicScore]
    )
}

final class SetlistsViewController: UITableViewController {
    weak var delegate: SetlistsViewControllerDelegate?

    private let repository: ScoreRepository
    private let scores: [MusicScore]
    private var setlists: [PerformanceSetlist] = []

    init(repository: ScoreRepository, scores: [MusicScore]) {
        self.repository = repository
        self.scores = scores
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = T("演出歌单", "Setlists")
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(createSetlist)
        )
        tableView.backgroundColor = ChordPressTheme.Color.surface
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = traitCollection.horizontalSizeClass == .regular ? 76 : 60
        tableView.sectionHeaderTopPadding = 20
        tableView.tableHeaderView = makeHeaderView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setlist")
        reloadSetlists()
    }

    private func makeHeaderView() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 92))
        let title = UILabel()
        title.text = T("为排练和现场演出安排曲目顺序", "Arrange songs for rehearsals and live sets")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = ChordPressTheme.Color.charcoal
        let detail = UILabel()
        detail.text = T("支持踏板连续翻页，演出时会提示下一首。", "Supports pedal page turns and next-song prompts during performance.")
        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.textColor = ChordPressTheme.Color.slate
        let stack = UIStackView(arrangedSubviews: [title, detail])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func reloadSetlists() {
        setlists = (try? repository.loadSetlists()) ?? []
        tableView.reloadData()
    }

    @objc private func createSetlist() {
        let alert = UIAlertController(title: T("新建演出歌单", "New Setlist"), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = T("例如：本周敬拜", "e.g. Sunday Service") }
        alert.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: T("创建", "Create"), style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            let setlist = PerformanceSetlist(id: UUID(), name: name, scoreIDs: [], updatedAt: Date())
            do {
                try self.repository.saveSetlist(setlist)
                self.reloadSetlists()
                self.openEditor(for: setlist)
            } catch {
                self.show(error)
            }
        })
        present(alert, animated: true)
    }

    private func openEditor(for setlist: PerformanceSetlist) {
        let editor = SetlistEditorViewController(
            setlist: setlist,
            scores: scores,
            repository: repository
        )
        editor.onChange = { [weak self] in self?.reloadSetlists() }
        editor.onPerform = { [weak self] performanceScores in
            guard let self else { return }
            self.delegate?.setlistsViewController(self, didRequestPerformance: performanceScores)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func show(_ error: Error) {
        let alert = UIAlertController(title: T("操作失败", "Operation Failed"), message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: T("好", "OK"), style: .default))
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        setlists.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setlist", for: indexPath)
        let setlist = setlists[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = setlist.name
        configuration.secondaryText = T("\(setlist.scoreIDs.count) 首乐谱", "\(setlist.scoreIDs.count) scores")
        configuration.image = UIImage(systemName: "music.note.list")
        configuration.textProperties.color = ChordPressTheme.Color.charcoal
        configuration.secondaryTextProperties.color = ChordPressTheme.Color.steel
        configuration.imageProperties.tintColor = ChordPressTheme.Color.primary
        cell.contentConfiguration = configuration
        cell.backgroundColor = ChordPressTheme.Color.canvas
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        openEditor(for: setlists[indexPath.row])
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        do {
            try repository.deleteSetlist(setlists[indexPath.row])
            reloadSetlists()
        } catch {
            show(error)
        }
    }
}

private final class SetlistEditorViewController: UITableViewController {
    var onChange: (() -> Void)?
    var onPerform: (([MusicScore]) -> Void)?

    private var setlist: PerformanceSetlist
    private let scores: [MusicScore]
    private let repository: ScoreRepository

    init(setlist: PerformanceSetlist, scores: [MusicScore], repository: ScoreRepository) {
        self.setlist = setlist
        self.scores = scores
        self.repository = repository
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = setlist.name
        tableView.backgroundColor = ChordPressTheme.Color.surface
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = traitCollection.horizontalSizeClass == .regular ? 68 : 56
        tableView.sectionHeaderTopPadding = 24
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                title: T("演出", "Perform"),
                image: UIImage(systemName: "play.fill"),
                target: self,
                action: #selector(startPerformance)
            ),
            editButtonItem,
            UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                menu: UIMenu(children: [
                    UIAction(title: T("重命名", "Rename"), image: UIImage(systemName: "pencil")) { [weak self] _ in
                        self?.renameSetlist()
                    }
                ])
            )
        ]
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Score")
    }

    private var orderedScores: [MusicScore] {
        setlist.scoreIDs.compactMap { id in scores.first { $0.id == id } }
    }

    private var availableScores: [MusicScore] {
        scores.filter { !setlist.scoreIDs.contains($0.id) }
    }

    private func persist() {
        setlist.updatedAt = Date()
        try? repository.saveSetlist(setlist)
        onChange?()
        tableView.reloadData()
    }

    private func renameSetlist() {
        let alert = UIAlertController(title: T("重命名歌单", "Rename Setlist"), message: nil, preferredStyle: .alert)
        alert.addTextField { [currentName = setlist.name] field in
            field.text = currentName
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: T("保存", "Save"), style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            self.setlist.name = name
            self.title = name
            self.persist()
        })
        present(alert, animated: true)
    }

    @objc private func startPerformance() {
        let selected = orderedScores
        guard !selected.isEmpty else { return }
        onPerform?(selected)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? T("演出顺序", "Performance Order") : T("添加乐谱", "Add Scores")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? orderedScores.count : availableScores.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Score", for: indexPath)
        let score = indexPath.section == 0 ? orderedScores[indexPath.row] : availableScores[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = score.title
        configuration.secondaryText = score.artist ?? score.sourceFormat.displayName
        configuration.image = UIImage(systemName: score.sourceFormat.symbolName)
        configuration.textProperties.color = ChordPressTheme.Color.charcoal
        configuration.secondaryTextProperties.color = ChordPressTheme.Color.steel
        configuration.imageProperties.tintColor = indexPath.section == 0
            ? ChordPressTheme.Color.primary
            : ChordPressTheme.Color.teal
        cell.contentConfiguration = configuration
        cell.backgroundColor = ChordPressTheme.Color.canvas
        cell.accessoryType = indexPath.section == 0 ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let score = indexPath.section == 0 ? orderedScores[indexPath.row] : availableScores[indexPath.row]
        if indexPath.section == 0 {
            setlist.scoreIDs.removeAll { $0 == score.id }
        } else {
            setlist.scoreIDs.append(score.id)
        }
        persist()
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        guard sourceIndexPath.section == 0, destinationIndexPath.section == 0 else { return }
        let id = setlist.scoreIDs.remove(at: sourceIndexPath.row)
        setlist.scoreIDs.insert(id, at: destinationIndexPath.row)
        persist()
    }
}
