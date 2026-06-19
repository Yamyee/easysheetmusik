这是为 ChordPress 准备的**技术实现文档**，重点覆盖了多格式乐谱支持的核心模块，以及基于 **Swift + UIKit** 的工程落地细节。

---

# ChordPress 技术文档 (V1.0)

## 1. 项目初始化与工程结构
**技术栈**：Swift 5.9+, UIKit, Auto Layout (SnapKit), Combine, Core Data + CloudKit
**架构**：MVVM-C (Model-View-ViewModel + Coordinator)
**依赖管理**：cocoapods

**核心目录结构**：
```
ChordPress/
├── App/                # AppDelegate, SceneDelegate, AppCoordinator
├── Models/             # 乐谱解析后的数据结构 (通用 MusicScore 模型)
├── Parsers/            # [核心] 多格式解析引擎
│   ├── PDFParser.swift
│   ├── ImageParser.swift
│   ├── ChordProParser.swift
│   └── MusicXMLParser.swift
├── Services/           # 同步服务、音频播放服务、文件管理
├── ViewModels/         # 业务逻辑层
├── Views/              # UIKit 视图
│   ├── Library/        # 曲库列表
│   ├── Reader/         # [核心] 乐谱阅览器
│   ├── Annotations/    # 标注系统
│   └── Editor/         # 和弦谱编辑器
└── Extensions/         # UIColor, UIView 等扩展
```

---

## 2. 多格式解析引擎设计 (Parser Protocol)

为支持 PDF, Image, ChordPro, MusicXML，需定义通用协议，屏蔽底层差异。UI层只关心最终的渲染模型。

```swift
// Models/MusicScore.swift
import Foundation

/// 所有格式解析后的统一数据模型
struct MusicScore {
    let id: UUID
    let title: String
    let artist: String?
    /// 渲染使用的页码
    let pages: [ScorePage]
    /// 原始格式元数据
    let sourceFormat: SourceFormat
}

struct ScorePage {
    /// 用于渲染的内容（PDF数据、图片、或属性字符串）
    let content: PageContent
    let number: Int
}

enum PageContent {
    case pdfData(Data)           // PDF的原始页面数据
    case image(UIImage)          // 图片
    case attributedText(NSAttributedString) // ChordPro/歌词
    case musicXMLScene(/* 矢量图形模型 */)   // 可缩放的矢量乐谱
}

enum SourceFormat {
    case pdf, image, chordPro, musicXML
}
```

**解析协议**：
```swift
// Parsers/ScoreParserProtocol.swift
protocol ScoreParserProtocol {
    /// 解析入口，接收原始数据，返回统一模型
    func parse(data: Data, fileName: String?) throws -> MusicScore
}
```

---

## 3. 核心格式解析实现 (P0/P1)

### 3.1 PDF 解析器
利用 `PDFKit` 提取每页为图片，方便后续统一标注层覆盖。

```swift
// Parsers/PDFParser.swift
import PDFKit

class PDFParser: ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let document = PDFDocument(data: data) else {
            throw ParserError.invalidFormat
        }
        
        var pages: [ScorePage] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            // 将PDF页转为图片，保持清晰度且方便标注
            let pageImage = page.thumbnail(of: page.bounds(for: .mediaBox).size, for: .mediaBox)
            pages.append(ScorePage(content: .image(pageImage), number: i + 1))
        }
        
        return MusicScore(
            id: UUID(),
            title: fileName ?? "未知乐谱",
            artist: document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
            pages: pages,
            sourceFormat: .pdf
        )
    }
}
```

### 3.2 图片解析器
需包含自动切边与增强功能，提升拍照导入体验。

```swift
// Parsers/ImageParser.swift
import UIKit
import Vision

class ImageParser: ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let image = UIImage(data: data) else {
            throw ParserError.invalidFormat
        }
        
        // 1. 矫正透视，切边处理
        let enhancedImage = self.enhanceImage(image)
        
        let page = ScorePage(content: .image(enhancedImage), number: 1)
        return MusicScore(id: UUID(), title: fileName ?? "图片乐谱", pages: [page], sourceFormat: .image)
    }
    
    private func enhanceImage(_ image: UIImage) -> UIImage {
        // TODO: 利用 Vision Framework 做矩形检测与透视矫正
        // 初期可先直接返回原图，V1.1加入图像增强
        return image
    }
}
```

### 3.3 ChordPro 解析器
将纯文本转为包含和弦图的 `NSAttributedString`，这是体验的关键。

```swift
// Parsers/ChordProParser.swift
import UIKit

class ChordProParser: ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ParserError.invalidFormat
        }
        
        let attributedString = parseChordProText(text)
        let page = ScorePage(content: .attributedText(attributedString), number: 1)
        // 简单的分页逻辑：通常单页滚动，或根据高度计算
        return MusicScore(id: UUID(), title: fileName ?? "和弦谱", pages: [page], sourceFormat: .chordPro)
    }
    
    private func parseChordProText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("{") {
                // 处理指令，如 {title: xxx}, 初期可跳过
                continue
            }
            // 简单解析：将 [C] 等和弦标记检测并上色/加粗
            let attributedLine = parseLineWithChords(line)
            result.append(attributedLine)
            result.append(NSAttributedString(string: "\n"))
        }
        return result
    }
    
    private func parseLineWithChords(_ line: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let pattern = "\\[.*?\\]" // 匹配 [Am] [C#] 等
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return NSAttributedString(string: line)
        }
        
        let nsString = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
        
        var lastIndex = 0
        for match in matches {
            // 添加和弦前的歌词
            let preText = nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
            result.append(NSAttributedString(string: preText))
            
            // 添加和弦（加粗、橙色、上方显示）
            let chordName = nsString.substring(with: match.range).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let chordAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.systemOrange
            ]
            result.append(NSAttributedString(string: chordName, attributes: chordAttributes))
            lastIndex = match.range.location + match.range.length
        }
        // 添加剩余歌词
        if lastIndex < nsString.length {
            let remaining = nsString.substring(from: lastIndex)
            result.append(NSAttributedString(string: remaining))
        }
        return result
    }
}
```

### 3.4 MusicXML 解析器 (P1)
使用 `XMLParser` 解析结构化音乐数据，渲染部分较复杂，此处仅展示解析骨架。

```swift
// Parsers/MusicXMLParser.swift
import Foundation

class MusicXMLParser: NSObject, ScoreParserProtocol, XMLParserDelegate {
    private var measures: [Measure] = []
    // ...
    
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        // 转换 measures 为自定义的矢量渲染模型
        let scene = MusicXMLScene(measures: measures)
        let page = ScorePage(content: .musicXMLScene(scene), number: 1)
        return MusicScore(id: UUID(), title: fileName ?? "乐谱", pages: [page], sourceFormat: .musicXML)
    }
    
    // XMLParserDelegate 方法: didStartElement, foundCharacters 等，用于填充 measures 数组
}
```

---

## 4. UIKit 核心界面实现

### 4.1 乐谱阅览器
阅览器由三层 UIKit 视图叠加构成：
- **底层 (内容层)**：`UIImageView` (图片/PDF)，`UITextView` (ChordPro)，或自定义 `MusicXMLView`。
- **中层 (标注层)**：自定义 `PKCanvasView` (PencilKit) 或自定义 `DrawingView`，透明背景。
- **顶层 (控制层)**：半透明工具栏，自动隐藏。

```swift
// Views/Reader/ScoreReaderViewController.swift
import UIKit
import PencilKit

class ScoreReaderViewController: UIViewController {
    private let viewModel: ScoreReaderViewModel
    private var contentView: UIView!   // 根据类型动态创建
    private var canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.tool = PKInkingTool(.pen, color: .systemYellow, width: 2)
        return canvas
    }()
    
    init(viewModel: ScoreReaderViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentView()
        setupCanvas()
        setupGestures()
    }
    
    private func setupContentView() {
        switch viewModel.score.pages.first?.content {
        case .image(let img):
            let imageView = UIImageView(image: img)
            imageView.contentMode = .scaleAspectFit
            contentView = imageView
        case .attributedText(let text):
            let textView = UITextView()
            textView.attributedText = text
            textView.isEditable = false
            contentView = textView
        default:
            contentView = UIView()
        }
        view.addSubview(contentView)
        contentView.frame = view.bounds
    }
    
    private func setupCanvas() {
        view.addSubview(canvasView)
        canvasView.frame = view.bounds
        // 允许双指滚动翻页，单指绘制
        canvasView.drawingGestureRecognizer.isEnabled = true
    }
    
    private func setupGestures() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(nextPage))
        swipe.direction = .left
        view.addGestureRecognizer(swipe)
    }
    
    @objc private func nextPage() { viewModel.nextPage() }
}
```

---

## 5. 数据持久化与跨设备同步

**方案**：**Core Data (本地) + CloudKit (自动镜像同步)**
`NSPersistentCloudKitContainer` 可自动将 Core Data 的 `NSManagedObject` 同步至 iCloud，无需自建后端。

**核心实体 (Core Data Model)**：
- `CDScore`: id, title, artist, sourceFormat, createdAt
- `CDPage`: pageNumber, imageData (或外部文件引用), textContent, annotationData (PKStrokeData)

**同步冲突策略**：CloudKit 默认“最后写入者胜”，对标注场景可接受。对于更安全的合并，可在更新前手动检查 `CKRecord` 的修改时间。

---

## 6. App Store 合规检查清单
- ✅ **NSPhotoLibraryUsageDescription**: 用于导入相册中的乐谱图片。
- ✅ **NSCameraUsageDescription**: 用于拍照直接生成乐谱。
- ✅ **UIFileSharingEnabled**: 允许 iTunes 文件共享导入。
- ✅ **iCloud Entitlements**: 启用 CloudKit 服务。
- ✅ **Privacy**: 明确声明“不扫描用户乐谱内容用于广告或分析”。
- ✅ **Encryption Compliance**: 如果仅用 Apple 提供的加密（如 CloudKit），在 App Store Connect 勾选 iOS 加密豁免。

---

这份文档给出了项目的骨架与核心难点解法。下一步建议先攻克 **PDF 阅览器 + PencilKit 标注**，这是所有乐手的核心入口。若需要其中某个模块的详细代码实现（如标注的擦除、还原逻辑，或 MusicXML 的详细解析状态机），可以告诉我，我再深化。
