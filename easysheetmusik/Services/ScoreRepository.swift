import PencilKit
import UIKit

final class ScoreRepository {
    private let fileManager: FileManager
    private let rootURL: URL
    private let scoresURL: URL
    private let annotationsURL: URL
    private let setlistsURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = applicationSupport.appendingPathComponent("ChordPress", isDirectory: true)
        scoresURL = rootURL.appendingPathComponent("Scores", isDirectory: true)
        annotationsURL = rootURL.appendingPathComponent("Annotations", isDirectory: true)
        setlistsURL = rootURL.appendingPathComponent("Setlists", isDirectory: true)
        try? fileManager.createDirectory(at: scoresURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: annotationsURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: setlistsURL, withIntermediateDirectories: true)
    }

    func loadScores() throws -> [MusicScore] {
        let urls = try fileManager.contentsOfDirectory(
            at: scoresURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(StoredScore.self, from: Data(contentsOf: $0)).musicScore }
            .sorted { $0.importedAt > $1.importedAt }
    }

    func save(_ score: MusicScore) throws {
        let data = try encoder.encode(StoredScore(score: score))
        try data.write(to: scoreURL(for: score.id), options: .atomic)
    }

    func delete(_ score: MusicScore) throws {
        let scoreURL = scoreURL(for: score.id)
        if fileManager.fileExists(atPath: scoreURL.path) {
            try fileManager.removeItem(at: scoreURL)
        }
        let annotationFolder = annotationsURL.appendingPathComponent(score.id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: annotationFolder.path) {
            try fileManager.removeItem(at: annotationFolder)
        }
    }

    func loadDrawing(scoreID: UUID, pageIndex: Int) -> PKDrawing {
        let url = annotationURL(scoreID: scoreID, pageIndex: pageIndex)
        guard let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    func saveDrawing(_ drawing: PKDrawing, scoreID: UUID, pageIndex: Int) throws {
        let folder = annotationsURL.appendingPathComponent(scoreID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try drawing.dataRepresentation().write(
            to: annotationURL(scoreID: scoreID, pageIndex: pageIndex),
            options: .atomic
        )
    }

    func loadSetlists() throws -> [PerformanceSetlist] {
        let urls = try fileManager.contentsOfDirectory(
            at: setlistsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(PerformanceSetlist.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveSetlist(_ setlist: PerformanceSetlist) throws {
        let data = try encoder.encode(setlist)
        try data.write(to: setlistURL(for: setlist.id), options: .atomic)
    }

    func deleteSetlist(_ setlist: PerformanceSetlist) throws {
        let url = setlistURL(for: setlist.id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func scoreURL(for id: UUID) -> URL {
        scoresURL.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func annotationURL(scoreID: UUID, pageIndex: Int) -> URL {
        annotationsURL
            .appendingPathComponent(scoreID.uuidString, isDirectory: true)
            .appendingPathComponent("\(pageIndex).drawing")
    }

    private func setlistURL(for id: UUID) -> URL {
        setlistsURL.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}

private struct StoredScore: Codable {
    let id: UUID
    let title: String
    let artist: String?
    let pages: [StoredPage]
    let sourceFormat: String
    let importedAt: Date
    let sourceText: String?
    let folder: String?
    let tags: [String]?
    let playbackEvents: [PlaybackEvent]?

    init(score: MusicScore) throws {
        id = score.id
        title = score.title
        artist = score.artist
        var storedPages: [StoredPage] = []
        for page in score.pages {
            storedPages.append(try StoredPage(page: page))
        }
        pages = storedPages
        sourceFormat = score.sourceFormat.rawValue
        importedAt = score.importedAt
        sourceText = score.sourceText
        folder = score.folder
        tags = score.tags
        playbackEvents = score.playbackEvents
    }

    var musicScore: MusicScore {
        get throws {
            guard let format = SourceFormat(rawValue: sourceFormat) else {
                throw ParserError.unsupportedFormat
            }
            return MusicScore(
                id: id,
                title: title,
                artist: artist,
                pages: try pages.map { try $0.scorePage },
                sourceFormat: format,
                importedAt: importedAt,
                sourceText: sourceText,
                folder: folder,
                tags: tags ?? [],
                playbackEvents: playbackEvents
            )
        }
    }
}

private struct StoredPage: Codable {
    enum ContentType: String, Codable {
        case image
        case attributedText
    }

    let number: Int
    let type: ContentType
    let data: Data

    init(page: ScorePage) throws {
        number = page.number
        switch page.content {
        case .image(let image):
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                throw ParserError.invalidFormat
            }
            type = .image
            data = imageData
        case .attributedText(let text):
            type = .attributedText
            data = try text.data(
                from: NSRange(location: 0, length: text.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
        }
    }

    var scorePage: ScorePage {
        get throws {
            switch type {
            case .image:
                guard let image = UIImage(data: data) else { throw ParserError.invalidFormat }
                return ScorePage(number: number, content: .image(image))
            case .attributedText:
                let text = try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                )
                return ScorePage(number: number, content: .attributedText(text))
            }
        }
    }
}
