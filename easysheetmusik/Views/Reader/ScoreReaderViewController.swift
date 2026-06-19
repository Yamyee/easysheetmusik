import PencilKit
import UIKit

final class ScoreReaderViewController: UIViewController {
    private let viewModel: ScoreReaderViewModel
    private let repository: ScoreRepository
    private let playbackService = ScorePlaybackService()
    private let contentContainer = UIView()
    private let canvasView = PKCanvasView()
    private let pageLabel = UILabel()
    private let performanceLabel = UILabel()
    private var toolPicker: PKToolPicker?
    private var isPerformanceMode = false
    private weak var activeScrollView: UIScrollView?
    private var scrollDisplayLink: CADisplayLink?
    private var lastScrollTimestamp: CFTimeInterval?
    private lazy var playButton = UIBarButtonItem(
        image: UIImage(systemName: "play.fill"),
        style: .plain,
        target: self,
        action: #selector(togglePlayback)
    )
    private lazy var autoScrollButton = UIBarButtonItem(
        image: UIImage(systemName: "arrow.down.to.line.compact"),
        style: .plain,
        target: self,
        action: #selector(toggleAutoScroll)
    )
    private lazy var annotationButton = UIBarButtonItem(
        image: UIImage(systemName: "pencil.tip"),
        style: .plain,
        target: self,
        action: #selector(toggleAnnotationMode)
    )

    init(viewModel: ScoreReaderViewModel, repository: ScoreRepository) {
        self.viewModel = viewModel
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.score.title
        navigationItem.largeTitleDisplayMode = .never
        var actions = [
            annotationButton,
            autoScrollButton,
            UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain,
                target: self,
                action: #selector(shareScore)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "rectangle.inset.filled"),
                style: .plain,
                target: self,
                action: #selector(togglePerformanceMode)
            )
        ]
        if viewModel.score.playbackEvents?.isEmpty == false {
            actions.insert(playButton, at: 0)
        }
        navigationItem.rightBarButtonItems = actions
        playbackService.onFinish = { [weak self] in
            self?.playButton.image = UIImage(systemName: "play.fill")
        }
        view.backgroundColor = .black
        configureHierarchy()
        configureGestures()
        showCurrentPage()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCurrentDrawing()
        stopAutoScroll()
        playbackService.stop()
    }

    private func configureHierarchy() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = .systemBackground
        view.addSubview(contentContainer)

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .systemOrange, width: 3)
        canvasView.isUserInteractionEnabled = false
        view.addSubview(canvasView)

        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        pageLabel.textColor = .white
        pageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        pageLabel.textAlignment = .center
        pageLabel.layer.cornerRadius = 14
        pageLabel.clipsToBounds = true
        view.addSubview(pageLabel)

        performanceLabel.translatesAutoresizingMaskIntoConstraints = false
        performanceLabel.font = .preferredFont(forTextStyle: .caption1)
        performanceLabel.textColor = .white
        performanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        performanceLabel.numberOfLines = 2
        performanceLabel.textAlignment = .center
        performanceLabel.layer.cornerRadius = 12
        performanceLabel.clipsToBounds = true
        view.addSubview(performanceLabel)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvasView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            pageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            pageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            pageLabel.heightAnchor.constraint(equalToConstant: 28),
            performanceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            performanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            performanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            performanceLabel.bottomAnchor.constraint(equalTo: pageLabel.topAnchor, constant: -8),
            performanceLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }

    private func configureGestures() {
        let previous = UISwipeGestureRecognizer(target: self, action: #selector(previousPage))
        previous.direction = .right
        previous.numberOfTouchesRequired = 2

        let next = UISwipeGestureRecognizer(target: self, action: #selector(nextPage))
        next.direction = .left
        next.numberOfTouchesRequired = 2

        view.addGestureRecognizer(previous)
        view.addGestureRecognizer(next)
    }

    private func showCurrentPage() {
        title = viewModel.score.title
        playbackService.stop()
        playButton.image = UIImage(systemName: "play.fill")
        refreshNavigationActions()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let contentView: UIView

        switch viewModel.currentPage.content {
        case .image(let image):
            let scrollView = UIScrollView()
            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = 5
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
            scrollView.delegate = self
            contentView = scrollView
            activeScrollView = scrollView

        case .attributedText(let text):
            let textView = UITextView()
            textView.attributedText = text
            textView.isEditable = false
            textView.textContainerInset = UIEdgeInsets(top: 28, left: 20, bottom: 80, right: 20)
            contentView = textView
            activeScrollView = textView
        }

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        canvasView.drawing = repository.loadDrawing(
            scoreID: viewModel.score.id,
            pageIndex: viewModel.currentPageIndex
        )
        pageLabel.text = viewModel.pageDescription
        pageLabel.isHidden = viewModel.score.pages.count <= 1
        if let setlistDescription = viewModel.setlistDescription {
            let next = viewModel.nextScoreTitle.map { "\n下一首：\($0)" } ?? "\n最后一首"
            performanceLabel.text = "歌单 \(setlistDescription)\(next)"
            performanceLabel.isHidden = false
        } else {
            performanceLabel.isHidden = true
        }
    }

    private func movePage(by offset: Int) {
        saveCurrentDrawing()
        if !viewModel.movePage(by: offset) {
            guard viewModel.moveScore(by: offset) else { return }
        }
        showCurrentPage()
    }

    @objc private func previousPage() {
        movePage(by: -1)
    }

    @objc private func nextPage() {
        movePage(by: 1)
    }

    @objc private func toggleAnnotationMode() {
        canvasView.isUserInteractionEnabled.toggle()
        annotationButton.image = UIImage(
            systemName: canvasView.isUserInteractionEnabled ? "pencil.tip.crop.circle.fill" : "pencil.tip"
        )
        annotationButton.accessibilityLabel = canvasView.isUserInteractionEnabled ? "退出标注" : "开始标注"
        if canvasView.isUserInteractionEnabled {
            let picker = PKToolPicker()
            picker.addObserver(canvasView)
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
            toolPicker = picker
        } else {
            toolPicker?.setVisible(false, forFirstResponder: canvasView)
            canvasView.resignFirstResponder()
            saveCurrentDrawing()
        }
    }

    private func saveCurrentDrawing() {
        try? repository.saveDrawing(
            canvasView.drawing,
            scoreID: viewModel.score.id,
            pageIndex: viewModel.currentPageIndex
        )
    }

    @objc private func shareScore() {
        let item: Any
        if let sourceText = viewModel.score.sourceText {
            item = sourceText
        } else {
            switch viewModel.currentPage.content {
            case .image(let image): item = image
            case .attributedText(let text): item = text.string
            }
        }
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(controller, animated: true)
    }

    @objc private func togglePerformanceMode() {
        isPerformanceMode.toggle()
        navigationController?.setNavigationBarHidden(isPerformanceMode, animated: true)
        performanceLabel.isHidden = !isPerformanceMode || viewModel.setlistDescription == nil
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    private func refreshNavigationActions() {
        var actions = [
            annotationButton,
            autoScrollButton,
            UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain,
                target: self,
                action: #selector(shareScore)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "rectangle.inset.filled"),
                style: .plain,
                target: self,
                action: #selector(togglePerformanceMode)
            )
        ]
        if viewModel.score.playbackEvents?.isEmpty == false {
            actions.insert(playButton, at: 0)
        }
        navigationItem.rightBarButtonItems = actions
    }

    @objc private func togglePlayback() {
        if playbackService.isPlaying {
            playbackService.stop()
            playButton.image = UIImage(systemName: "play.fill")
            return
        }
        guard let events = viewModel.score.playbackEvents else { return }
        do {
            try playbackService.play(events: events)
            playButton.image = UIImage(systemName: "stop.fill")
        } catch {
            let alert = UIAlertController(
                title: "无法播放",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func toggleAutoScroll() {
        if scrollDisplayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(updateAutoScroll))
            displayLink.add(to: .main, forMode: .common)
            scrollDisplayLink = displayLink
            autoScrollButton.image = UIImage(systemName: "pause.fill")
        } else {
            stopAutoScroll()
        }
    }

    @objc private func updateAutoScroll(_ displayLink: CADisplayLink) {
        guard let scrollView = activeScrollView else {
            stopAutoScroll()
            return
        }
        let previous = lastScrollTimestamp ?? displayLink.timestamp
        lastScrollTimestamp = displayLink.timestamp
        let delta = displayLink.timestamp - previous
        let maximumOffset = max(
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom,
            0
        )
        let nextOffset = min(scrollView.contentOffset.y + CGFloat(delta * 24), maximumOffset)
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: nextOffset), animated: false)
        if nextOffset >= maximumOffset {
            stopAutoScroll()
        }
    }

    private func stopAutoScroll() {
        scrollDisplayLink?.invalidate()
        scrollDisplayLink = nil
        lastScrollTimestamp = nil
        autoScrollButton.image = UIImage(systemName: "arrow.down.to.line.compact")
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        isPerformanceMode
    }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(previousPage)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(nextPage)),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(previousPage)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(nextPage)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(nextPage))
        ]
    }
}

extension ScoreReaderViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView.subviews.first
    }
}
