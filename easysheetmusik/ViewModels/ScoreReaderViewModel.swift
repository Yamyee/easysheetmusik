import Foundation

final class ScoreReaderViewModel {
    private let scores: [MusicScore]
    private(set) var currentScoreIndex: Int
    private(set) var currentPageIndex = 0

    init(scores: [MusicScore], startIndex: Int = 0) {
        self.scores = scores
        currentScoreIndex = min(max(startIndex, 0), max(scores.count - 1, 0))
    }

    convenience init(score: MusicScore) {
        self.init(scores: [score])
    }

    var score: MusicScore {
        scores[currentScoreIndex]
    }

    var currentPage: ScorePage {
        score.pages[currentPageIndex]
    }

    var pageDescription: String {
        "\(currentPageIndex + 1) / \(score.pages.count)"
    }

    var setlistDescription: String? {
        guard scores.count > 1 else { return nil }
        return "\(currentScoreIndex + 1) / \(scores.count)"
    }

    var nextScoreTitle: String? {
        let nextIndex = currentScoreIndex + 1
        guard scores.indices.contains(nextIndex) else { return nil }
        return scores[nextIndex].title
    }

    @discardableResult
    func movePage(by offset: Int) -> Bool {
        let nextIndex = currentPageIndex + offset
        guard score.pages.indices.contains(nextIndex) else { return false }
        currentPageIndex = nextIndex
        return true
    }

    @discardableResult
    func moveScore(by offset: Int) -> Bool {
        let nextIndex = currentScoreIndex + offset
        guard scores.indices.contains(nextIndex) else { return false }
        currentScoreIndex = nextIndex
        currentPageIndex = offset > 0 ? 0 : max(score.pages.count - 1, 0)
        return true
    }
}
