import UIKit

final class ImageParser: ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let image = UIImage(data: data) else {
            throw ParserError.invalidFormat
        }

        let title = fileName.map { ($0 as NSString).deletingPathExtension } ?? "图片乐谱"
        return MusicScore(
            id: UUID(),
            title: title,
            artist: nil,
            pages: [ScorePage(number: 1, content: .image(image))],
            sourceFormat: .image,
            importedAt: Date(),
            sourceText: nil,
            folder: nil,
            playbackEvents: nil
        )
    }
}
