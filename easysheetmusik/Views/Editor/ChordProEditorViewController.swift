import UIKit

protocol ChordProEditorViewControllerDelegate: AnyObject {
    func chordProEditor(_ editor: ChordProEditorViewController, didSave text: String, scoreID: UUID?)
}

final class ChordProEditorViewController: UIViewController {
    weak var delegate: ChordProEditorViewControllerDelegate?

    private let scoreID: UUID?
    private let textView = UITextView()
    private let previewView = UITextView()
    private let segmentedControl = UISegmentedControl(items: ["编辑", "预览"])
    private let transposer = ChordTransposer()

    init(score: MusicScore? = nil) {
        scoreID = score?.id
        super.init(nibName: nil, bundle: nil)
        textView.text = score?.sourceText ?? """
        {title: 未命名和弦谱}
        {artist: }

        [C]在这里输入歌词和[Am]和弦
        """
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = scoreID == nil ? "新建 ChordPro" : "编辑 ChordPro"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(save)
        )
        configureViews()
        updatePreview()
    }

    private func configureViews() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(changeMode), for: .valueChanged)
        navigationItem.titleView = segmentedControl

        textView.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.keyboardDismissMode = .interactive

        previewView.isEditable = false
        previewView.isHidden = true
        previewView.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 40, right: 20)

        let downButton = makeTransposeButton(title: "降半音", image: "minus", action: #selector(transposeDown))
        let upButton = makeTransposeButton(title: "升半音", image: "plus", action: #selector(transposeUp))
        let toolbar = UIStackView(arrangedSubviews: [downButton, upButton])
        toolbar.distribution = .fillEqually
        toolbar.spacing = 12

        [textView, previewView, toolbar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toolbar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -10),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8),
            previewView.topAnchor.constraint(equalTo: textView.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: textView.bottomAnchor)
        ])
    }

    private func makeTransposeButton(title: String, image: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: image)
        configuration.imagePadding = 6
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updatePreview() {
        guard let score = try? ChordProParser().parse(
            data: Data(textView.text.utf8),
            fileName: nil
        ), case .attributedText(let text) = score.pages.first?.content else {
            previewView.text = "暂无可预览内容"
            return
        }
        previewView.attributedText = text
    }

    private func transpose(by semitones: Int) {
        textView.text = transposer.transpose(textView.text, semitones: semitones)
        updatePreview()
    }

    @objc private func changeMode() {
        let previewing = segmentedControl.selectedSegmentIndex == 1
        if previewing { updatePreview() }
        textView.isHidden = previewing
        previewView.isHidden = !previewing
        view.endEditing(previewing)
    }

    @objc private func transposeDown() {
        transpose(by: -1)
    }

    @objc private func transposeUp() {
        transpose(by: 1)
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func save() {
        guard textView.text.contains(where: { !$0.isWhitespace }) else { return }
        delegate?.chordProEditor(self, didSave: textView.text, scoreID: scoreID)
    }
}
