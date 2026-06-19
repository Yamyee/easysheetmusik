import UIKit

final class LibraryViewModel {
    private(set) var scores: [MusicScore] = []
    private let importService = ScoreImportService()
    private let repository: ScoreRepository
    private let entitlementService: AppEntitlementService
    private(set) var searchText = ""
    private(set) var selectedFolder: String?
    private(set) var selectedTag: String?

    var onChange: (() -> Void)?

    init(repository: ScoreRepository, entitlementService: AppEntitlementService = .shared) {
        self.repository = repository
        self.entitlementService = entitlementService
        scores = (try? repository.loadScores()) ?? []
    }

    var visibleScores: [MusicScore] {
        scores.filter { score in
            let matchesFolder = selectedFolder == nil || score.folder == selectedFolder
            let matchesTag = selectedTag.map { selected in
                score.tags.contains(selected)
            } ?? true
            let matchesSearch = searchText.isEmpty
                || score.title.localizedCaseInsensitiveContains(searchText)
                || (score.artist?.localizedCaseInsensitiveContains(searchText) == true)
                || score.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesFolder && matchesTag && matchesSearch
        }
    }

    var folders: [String] {
        Array(Set(scores.compactMap(\.folder))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var tags: [String] {
        Array(Set(scores.flatMap(\.tags))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var selectedFolderTitle: String {
        selectedFolder ?? T("全部乐谱", "All Scores")
    }

    func selectFolder(_ folder: String?) {
        selectedFolder = folder
        onChange?()
    }

    func selectTag(_ tag: String?) {
        selectedTag = tag
        onChange?()
    }

    func moveScore(_ score: MusicScore, to folder: String?) throws {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }
        scores[index].folder = folder
        try repository.save(scores[index])
        onChange?()
    }

    func updateTags(for score: MusicScore, tags: [String]) throws {
        guard let index = scores.firstIndex(where: { $0.id == score.id }) else { return }
        scores[index].tags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    func importImage(_ image: UIImage, title: String = T("图片乐谱", "Image Score")) throws {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw ParserError.invalidFormat
        }
        try add(ImageParser().parse(data: data, fileName: title))
    }

    func saveChordPro(text: String, replacing scoreID: UUID? = nil) throws -> MusicScore {
        var score = try ChordProParser().parse(
            data: Data(text.utf8),
            fileName: "\(T("未命名和弦谱", "Untitled ChordPro")).cho"
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
                tags: oldScore.tags,
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
        guard entitlementService.canAddScore(currentCount: scores.count) else {
            throw EntitlementError.scoreLimitReached
        }
        var score = newScore
        score.folder = selectedFolder
        if let selectedTag, !score.tags.contains(selectedTag) {
            score.tags.append(selectedTag)
        }
        try repository.save(score)
        scores.insert(score, at: 0)
        onChange?()
    }
}
