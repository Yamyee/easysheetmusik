import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let navigationController = UINavigationController()
    private let repository = ScoreRepository()
    private lazy var libraryViewModel = LibraryViewModel(repository: repository)

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        let library = LibraryViewController(viewModel: libraryViewModel)
        library.delegate = self
        navigationController.setViewControllers([library], animated: false)
        navigationController.navigationBar.prefersLargeTitles = true
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }
}

extension AppCoordinator: LibraryViewControllerDelegate {
    func libraryViewController(_ viewController: LibraryViewController, didSelect score: MusicScore) {
        let reader = ScoreReaderViewController(
            viewModel: ScoreReaderViewModel(score: score),
            repository: repository
        )
        navigationController.pushViewController(reader, animated: true)
    }

    func libraryViewControllerDidRequestNewChordPro(_ viewController: LibraryViewController) {
        presentEditor(score: nil)
    }

    func libraryViewController(_ viewController: LibraryViewController, didRequestEdit score: MusicScore) {
        presentEditor(score: score)
    }

    func libraryViewControllerDidRequestSetlists(_ viewController: LibraryViewController) {
        let setlists = SetlistsViewController(repository: repository, scores: libraryViewModel.scores)
        setlists.delegate = self
        navigationController.pushViewController(setlists, animated: true)
    }

    private func presentEditor(score: MusicScore?) {
        let editor = ChordProEditorViewController(score: score)
        editor.delegate = self
        navigationController.present(UINavigationController(rootViewController: editor), animated: true)
    }
}

extension AppCoordinator: SetlistsViewControllerDelegate {
    func setlistsViewController(
        _ viewController: SetlistsViewController,
        didRequestPerformance scores: [MusicScore]
    ) {
        let reader = ScoreReaderViewController(
            viewModel: ScoreReaderViewModel(scores: scores),
            repository: repository
        )
        navigationController.pushViewController(reader, animated: true)
    }
}

extension AppCoordinator: ChordProEditorViewControllerDelegate {
    func chordProEditor(_ editor: ChordProEditorViewController, didSave text: String, scoreID: UUID?) {
        do {
            _ = try libraryViewModel.saveChordPro(text: text, replacing: scoreID)
            editor.dismiss(animated: true)
        } catch {
            let alert = UIAlertController(
                title: "保存失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好", style: .default))
            editor.present(alert, animated: true)
        }
    }
}
