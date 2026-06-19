import UIKit

final class LibraryViewModel {
    private(set) var scores: [MusicScore] = []
    private let importService = ScoreImportService()
    private let repository: ScoreRepository
    private(set) var searchText = ""
    private(set) var selectedFolder: String?

    var onChange: (() -> Void)?

    init(repository: ScoreRepository) {
        self.repository = repository
        scores = (try? repository.loadScores()) ?? []
    }

    var visibleScores: [MusicScore] {
        scores.filter {
            let matchesFolder = selectedFolder == nil || $0.folder == selectedFolder
            let matchesSearch = searchText.isEmpty
                || $0.title.localizedCaseInsensitiveContains(searchText)
                || ($0.artist?.localizedCaseInsensitiveContains(searchText) == true)
            return matchesFolder && matchesSearch
        }
    }

    var folders: [String] {
        Array(Set(scores.compactMap(\.folder))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var selectedFolderTitle: String {
        selectedFolder ?? "全部乐谱"
    }

    func selectFolder(_ folder: String?) {
        selectedFolder = folder
        onChange?()
    }

    func moveScore(_ score: MusicScore, to folder: String?) throws {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }
        scores[index].folder = folder
        try repository.save(scores[index])
        onChange?()
    }

    func createFolder(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedFolder = trimmed
        onChange?()
    }

    func importScore(from url: URL) throws {
        let score = try importService.importScore(from: url)
        try add(score)
    }

    func importImage(_ image: UIImage, title: String = "图片乐谱") throws {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw ParserError.invalidFormat
        }
        try add(ImageParser().parse(data: data, fileName: title))
    }

    func saveChordPro(text: String, replacing scoreID: UUID? = nil) throws -> MusicScore {
        var score = try ChordProParser().parse(
            data: Data(text.utf8),
            fileName: "未命名和弦谱.cho"
        )
        if let scoreID, let existingIndex = scores.firstIndex(where: { $0.id == scoreID }) {
            let oldScore = scores[existingIndex]
            score = MusicScore(
                id: oldScore.id,
                title: score.title,
                artist: score.artist,
                pages: score.pages,
                sourceFormat: .chordPro,
                importedAt: oldScore.importedAt,
                sourceText: text,
                folder: oldScore.folder,
                playbackEvents: nil
            )
            scores[existingIndex] = score
            try repository.save(score)
        } else {
            try add(score)
        }
        onChange?()
        return score
    }

    func deleteScore(at visibleIndex: Int) throws {
        let score = visibleScores[visibleIndex]
        try repository.delete(score)
        scores.removeAll { $0.id == score.id }
        onChange?()
    }

    func setSearchText(_ text: String) {
        searchText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        onChange?()
    }

    private func add(_ newScore: MusicScore) throws {
        var score = newScore
        score.folder = selectedFolder
        try repository.save(score)
        scores.insert(score, at: 0)
        onChange?()
    }
}
