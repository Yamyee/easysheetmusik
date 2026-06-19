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
    private let annotationToolbar = UIStackView()
    private let playbackProgressView = UIProgressView(progressViewStyle: .bar)
    private let transposer = ChordTransposer()
    private var toolPicker: PKToolPicker?
    private var isPerformanceMode = false
    private var transposition = 0
    private weak var activeScrollView: UIScrollView?
    private var scrollDisplayLink: CADisplayLink?
    private var lastScrollTimestamp: CFTimeInterval?
    private var playbackTimer: Timer?
    private var playbackElapsed: TimeInterval = 0
    private var playbackDuration: TimeInterval = 0
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
    private lazy var transposeButton = UIBarButtonItem(
        image: UIImage(systemName: "music.note"),
        style: .plain,
        target: self,
        action: #selector(showTransposeMenu)
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
        configureNavigationAppearance()
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
            self?.stopPlaybackProgress()
        }
        view.backgroundColor = ChordPressTheme.Color.brandNavyDeep
        configureHierarchy()
        configureGestures()
        showCurrentPage()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCurrentDrawing()
        stopAutoScroll()
        playbackService.stop()
        stopPlaybackProgress()
    }

    private func configureHierarchy() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = ChordPressTheme.Color.canvas
        contentContainer.layer.cornerRadius = traitCollection.horizontalSizeClass == .regular ? ChordPressTheme.Radius.card : 0
        contentContainer.layer.cornerCurve = .continuous
        contentContainer.layer.shadowColor = ChordPressTheme.Color.ink.cgColor
        contentContainer.layer.shadowOpacity = traitCollection.horizontalSizeClass == .regular ? 0.22 : 0
        contentContainer.layer.shadowRadius = 20
        contentContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.addSubview(contentContainer)

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: ChordPressTheme.Color.orange, width: 3)
        canvasView.isUserInteractionEnabled = false
        view.addSubview(canvasView)

        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        pageLabel.textColor = ChordPressTheme.Color.onDark
        pageLabel.backgroundColor = ChordPressTheme.Color.brandNavyMid.withAlphaComponent(0.88)
        pageLabel.textAlignment = .center
        pageLabel.layer.cornerRadius = 14
        pageLabel.clipsToBounds = true
        view.addSubview(pageLabel)

        performanceLabel.translatesAutoresizingMaskIntoConstraints = false
        performanceLabel.font = .preferredFont(forTextStyle: .caption1)
        performanceLabel.textColor = ChordPressTheme.Color.onDark
        performanceLabel.backgroundColor = ChordPressTheme.Color.brandNavy.withAlphaComponent(0.9)
        performanceLabel.numberOfLines = 2
        performanceLabel.textAlignment = .center
        performanceLabel.layer.cornerRadius = 12
        performanceLabel.clipsToBounds = true
        view.addSubview(performanceLabel)

        configureAnnotationToolbar()

        playbackProgressView.translatesAutoresizingMaskIntoConstraints = false
        playbackProgressView.progressTintColor = ChordPressTheme.Color.primary
        playbackProgressView.trackTintColor = ChordPressTheme.Color.brandNavyMid.withAlphaComponent(0.35)
        playbackProgressView.isHidden = true
        view.addSubview(playbackProgressView)

        let paperConstraints: [NSLayoutConstraint]
        if traitCollection.horizontalSizeClass == .regular {
            let preferredWidth = contentContainer.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -64)
            preferredWidth.priority = .defaultHigh
            paperConstraints = [
                contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
                contentContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
                contentContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                preferredWidth,
                contentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 1100),
                contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
                contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
            ]
        } else {
            paperConstraints = [
                contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
        }

        NSLayoutConstraint.activate(paperConstraints + [
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
            performanceLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            annotationToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            annotationToolbar.bottomAnchor.constraint(equalTo: performanceLabel.topAnchor, constant: -10),
            annotationToolbar.heightAnchor.constraint(equalToConstant: 44),
            playbackProgressView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            playbackProgressView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            playbackProgressView.topAnchor.constraint(equalTo: contentContainer.topAnchor)
        ])
    }

    private func configureAnnotationToolbar() {
        annotationToolbar.translatesAutoresizingMaskIntoConstraints = false
        annotationToolbar.axis = .horizontal
        annotationToolbar.spacing = 8
        annotationToolbar.alignment = .center
        annotationToolbar.distribution = .fillEqually
        annotationToolbar.backgroundColor = ChordPressTheme.Color.brandNavy.withAlphaComponent(0.9)
        annotationToolbar.layer.cornerRadius = ChordPressTheme.Radius.card
        annotationToolbar.isLayoutMarginsRelativeArrangement = true
        annotationToolbar.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        annotationToolbar.isHidden = true

        [
            makeToolButton(image: "pencil", action: #selector(selectPenTool)),
            makeToolButton(image: "highlighter", action: #selector(selectHighlighterTool)),
            makeToolButton(image: "eraser", action: #selector(selectEraserTool)),
            makeToolButton(image: "arrow.uturn.backward", action: #selector(undoAnnotation)),
            makeToolButton(image: "arrow.uturn.forward", action: #selector(redoAnnotation))
        ].forEach(annotationToolbar.addArrangedSubview)
        view.addSubview(annotationToolbar)
    }

    private func makeToolButton(image: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.image = UIImage(systemName: image)
        configuration.baseForegroundColor = ChordPressTheme.Color.onDark
        configuration.baseBackgroundColor = ChordPressTheme.Color.onDark.withAlphaComponent(0.14)
        configuration.background.cornerRadius = ChordPressTheme.Radius.button
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        appearance.backgroundColor = ChordPressTheme.Color.brandNavy.withAlphaComponent(0.86)
        appearance.titleTextAttributes = [.foregroundColor: ChordPressTheme.Color.onDark]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
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

        let exitPerformance = UILongPressGestureRecognizer(target: self, action: #selector(exitPerformanceModeGesture))
        exitPerformance.minimumPressDuration = 2
        exitPerformance.numberOfTouchesRequired = 3
        view.addGestureRecognizer(exitPerformance)
    }

    private func showCurrentPage() {
        title = viewModel.score.title
        playbackService.stop()
        playButton.image = UIImage(systemName: "play.fill")
        refreshNavigationActions()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let contentView: UIView

        let pageContent = renderedContentForCurrentState()

        switch pageContent {
        case .image(let image):
            let scrollView = UIScrollView()
            scrollView.backgroundColor = ChordPressTheme.Color.surfaceSoft
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
            textView.backgroundColor = ChordPressTheme.Color.canvas
            let horizontalInset: CGFloat = traitCollection.horizontalSizeClass == .regular ? 56 : 20
            textView.textContainerInset = UIEdgeInsets(
                top: traitCollection.horizontalSizeClass == .regular ? 48 : 28,
                left: horizontalInset,
                bottom: 100,
                right: horizontalInset
            )
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
            let next = viewModel.nextScoreTitle.map {
                T("\n下一首：\($0)", "\nNext: \($0)")
            } ?? T("\n最后一首", "\nLast song")
            performanceLabel.text = T("歌单 \(setlistDescription)\(next)", "Setlist \(setlistDescription)\(next)")
            performanceLabel.isHidden = false
        } else {
            performanceLabel.isHidden = true
        }
    }

    private func renderedContentForCurrentState() -> PageContent {
        guard transposition != 0,
              viewModel.score.sourceFormat == .chordPro,
              let sourceText = viewModel.score.sourceText,
              let score = try? ChordProParser().parse(
                data: Data(transposer.transpose(sourceText, semitones: transposition).utf8),
                fileName: viewModel.score.title
              ),
              let page = score.pages.first else {
            return viewModel.currentPage.content
        }
        return page.content
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
        annotationButton.accessibilityLabel = canvasView.isUserInteractionEnabled
            ? T("退出标注", "Exit Annotation")
            : T("开始标注", "Start Annotation")
        annotationToolbar.isHidden = !canvasView.isUserInteractionEnabled
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

    @objc private func selectPenTool() {
        canvasView.tool = PKInkingTool(.pen, color: ChordPressTheme.Color.orange, width: 3)
    }

    @objc private func selectHighlighterTool() {
        canvasView.tool = PKInkingTool(.marker, color: ChordPressTheme.Color.yellow.withAlphaComponent(0.5), width: 10)
    }

    @objc private func selectEraserTool() {
        canvasView.tool = PKEraserTool(.bitmap)
    }

    @objc private func undoAnnotation() {
        canvasView.undoManager?.undo()
    }

    @objc private func redoAnnotation() {
        canvasView.undoManager?.redo()
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
        annotationToolbar.isHidden = true
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    @objc private func exitPerformanceModeGesture(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, isPerformanceMode else { return }
        togglePerformanceMode()
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
        if viewModel.score.sourceFormat == .chordPro {
            actions.insert(transposeButton, at: 0)
        }
        if viewModel.score.playbackEvents?.isEmpty == false {
            actions.insert(playButton, at: 0)
        }
        navigationItem.rightBarButtonItems = actions
    }

    @objc private func showTransposeMenu() {
        let alert = UIAlertController(title: T("转调", "Transpose"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: T("升半音", "Up Semitone"), style: .default) { [weak self] _ in
            self?.transposeReader(by: 1)
        })
        alert.addAction(UIAlertAction(title: T("降半音", "Down Semitone"), style: .default) { [weak self] _ in
            self?.transposeReader(by: -1)
        })
        alert.addAction(UIAlertAction(title: T("还原原调", "Reset Key"), style: .default) { [weak self] _ in
            self?.transposition = 0
            self?.showCurrentPage()
        })
        alert.addAction(UIAlertAction(title: T("取消", "Cancel"), style: .cancel))
        alert.popoverPresentationController?.barButtonItem = transposeButton
        present(alert, animated: true)
    }

    private func transposeReader(by semitones: Int) {
        transposition += semitones
        showCurrentPage()
    }

    @objc private func togglePlayback() {
        if playbackService.isPlaying {
            playbackService.stop()
            stopPlaybackProgress()
            playButton.image = UIImage(systemName: "play.fill")
            return
        }
        guard let events = viewModel.score.playbackEvents else { return }
        do {
            try playbackService.play(events: events)
            playButton.image = UIImage(systemName: "stop.fill")
            startPlaybackProgress(duration: events.reduce(0) { $0 + $1.duration })
        } catch {
            let alert = UIAlertController(
                title: T("无法播放", "Playback Unavailable"),
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: T("好", "OK"), style: .default))
            present(alert, animated: true)
        }
    }

    private func startPlaybackProgress(duration: TimeInterval) {
        playbackTimer?.invalidate()
        playbackDuration = max(duration, 0.1)
        playbackElapsed = 0
        playbackProgressView.progress = 0
        playbackProgressView.isHidden = false
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.playbackElapsed += 0.05
            self.playbackProgressView.progress = Float(min(self.playbackElapsed / self.playbackDuration, 1))
            if self.playbackElapsed >= self.playbackDuration {
                timer.invalidate()
            }
        }
    }

    private func stopPlaybackProgress() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        playbackProgressView.isHidden = true
        playbackProgressView.progress = 0
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
