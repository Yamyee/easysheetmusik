import Foundation
import UniformTypeIdentifiers

final class ScoreImportService {
    func importScore(from url: URL) throws -> MusicScore {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let parser = try parser(for: url, data: data)
        return try parser.parse(data: data, fileName: url.lastPathComponent)
    }

    private func parser(for url: URL, data: Data) throws -> ScoreParserProtocol {
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType

        if type?.conforms(to: .pdf) == true { return PDFParser() }
        if type?.conforms(to: .image) == true { return ImageParser() }

        let extensionName = url.pathExtension.lowercased()
        if ["musicxml", "xml"].contains(extensionName) {
            return MusicXMLParser()
        }
        if ["tab"].contains(extensionName) {
            return TabParser()
        }
        if extensionName == "txt" {
            let text = String(data: data, encoding: .utf8) ?? ""
            return looksLikeTab(text) ? TabParser() : ChordProParser()
        }
        if ["cho", "chordpro", "chopro", "crd"].contains(extensionName) {
            return ChordProParser()
        }

        throw ParserError.unsupportedFormat
    }

    private func looksLikeTab(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let tabLines = lines.filter { line in
            line.range(of: #"^\s*[EADGBe]\|[-0-9hHpPbBrR/\\~xX| ]+$"#, options: .regularExpression) != nil
        }
        return tabLines.count >= 3
    }
}
