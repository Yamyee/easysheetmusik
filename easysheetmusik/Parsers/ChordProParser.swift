import UIKit

final class ChordProParser: ScoreParserProtocol {
    private let directivePattern = #"^\{\s*([^:}]+)\s*:\s*(.*?)\s*\}$"#
    private let chordPattern = #"\[([^\]]+)\]"#

    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ParserError.invalidFormat
        }

        var title: String?
        var artist: String?
        let rendered = NSMutableAttributedString()

        for line in text.components(separatedBy: .newlines) {
            if let directive = parseDirective(line) {
                switch directive.key.lowercased() {
                case "title", "t": title = directive.value
                case "artist", "subtitle", "st": artist = directive.value
                default: break
                }
                continue
            }

            rendered.append(renderLine(line))
            rendered.append(NSAttributedString(string: "\n"))
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        rendered.addAttributes(
            [.font: UIFont.systemFont(ofSize: 19), .paragraphStyle: paragraph],
            range: NSRange(location: 0, length: rendered.length)
        )

        guard rendered.string.contains(where: { !$0.isWhitespace }) else {
            throw ParserError.emptyDocument
        }

        let fallbackTitle = fileName.map { ($0 as NSString).deletingPathExtension } ?? "未命名和弦谱"
        return MusicScore(
            id: UUID(),
            title: title ?? fallbackTitle,
            artist: artist,
            pages: [ScorePage(number: 1, content: .attributedText(rendered))],
            sourceFormat: .chordPro,
            importedAt: Date(),
            sourceText: text,
            folder: nil,
            playbackEvents: nil
        )
    }

    private func parseDirective(_ line: String) -> (key: String, value: String)? {
        guard let regex = try? NSRegularExpression(pattern: directivePattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keyRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (String(line[keyRange]), String(line[valueRange]))
    }

    private func renderLine(_ line: String) -> NSAttributedString {
        guard let regex = try? NSRegularExpression(pattern: chordPattern) else {
            return NSAttributedString(string: line)
        }

        let result = NSMutableAttributedString()
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        var cursor = line.startIndex

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: line),
                  let chordRange = Range(match.range(at: 1), in: line) else { continue }
            result.append(NSAttributedString(string: String(line[cursor..<fullRange.lowerBound])))
            result.append(NSAttributedString(
                string: String(line[chordRange]),
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: UIColor.systemOrange,
                    .baselineOffset: 5
                ]
            ))
            cursor = fullRange.upperBound
        }

        result.append(NSAttributedString(string: String(line[cursor...])))
        return result
    }
}
