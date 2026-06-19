import UIKit

final class TabParser: ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let text = String(data: data, encoding: .utf8),
              text.contains(where: { !$0.isWhitespace }) else {
            throw ParserError.invalidFormat
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let rendered = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
        )
        let title = fileName.map { ($0 as NSString).deletingPathExtension } ?? "文本 Tab"
        return MusicScore(
            id: UUID(),
            title: title,
            artist: nil,
            pages: [ScorePage(number: 1, content: .attributedText(rendered))],
            sourceFormat: .tab,
            importedAt: Date(),
            sourceText: text,
            folder: nil,
            playbackEvents: nil
        )
    }
}
