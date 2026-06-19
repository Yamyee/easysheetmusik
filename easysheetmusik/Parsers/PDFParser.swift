import PDFKit

final class PDFParser: ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let document = PDFDocument(data: data) else {
            throw ParserError.invalidFormat
        }

        let pages = (0..<document.pageCount).compactMap { index -> ScorePage? in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(2, 2400 / max(bounds.width, bounds.height))
            let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            return ScorePage(
                number: index + 1,
                content: .image(page.thumbnail(of: renderSize, for: .mediaBox))
            )
        }

        guard !pages.isEmpty else { throw ParserError.emptyDocument }
        let attributes = document.documentAttributes
        let metadataTitle = attributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = attributes?[PDFDocumentAttribute.authorAttribute] as? String

        return MusicScore(
            id: UUID(),
            title: metadataTitle?.nonEmpty ?? displayName(from: fileName, fallback: "未命名 PDF"),
            artist: author?.nonEmpty,
            pages: pages,
            sourceFormat: .pdf,
            importedAt: Date(),
            sourceText: nil,
            folder: nil,
            playbackEvents: nil
        )
    }

    private func displayName(from fileName: String?, fallback: String) -> String {
        guard let fileName else { return fallback }
        return (fileName as NSString).deletingPathExtension.nonEmpty ?? fallback
    }
}

private extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
