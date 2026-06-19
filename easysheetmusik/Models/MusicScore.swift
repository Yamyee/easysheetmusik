import UIKit

struct MusicScore: Identifiable {
    let id: UUID
    var title: String
    var artist: String?
    let pages: [ScorePage]
    let sourceFormat: SourceFormat
    let importedAt: Date
    var sourceText: String?
    var folder: String?
    var tags: [String]
    var playbackEvents: [PlaybackEvent]?
}

struct PlaybackEvent: Codable {
    let midiNote: UInt8?
    let duration: TimeInterval
}

struct ScorePage {
    let number: Int
    let content: PageContent
}

enum PageContent {
    case image(UIImage)
    case attributedText(NSAttributedString)
}

enum SourceFormat: String {
    case pdf = "PDF"
    case image = "图片"
    case chordPro = "ChordPro"
    case musicXML = "MusicXML"
    case tab = "Tab"

    var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .image: T("图片", "Image")
        case .chordPro: "ChordPro"
        case .musicXML: "MusicXML"
        case .tab: "Tab"
        }
    }

    var symbolName: String {
        switch self {
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .chordPro: "music.note.list"
        case .musicXML: "music.quarternote.3"
        case .tab: "guitars"
        }
    }
}
