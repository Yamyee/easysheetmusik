import Foundation

final class AppEntitlementService {
    static let shared = AppEntitlementService()

    private let defaults: UserDefaults
    private let proKey = "ChordPress.isProUnlocked"

    let freeScoreLimit = 15

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isProUnlocked: Bool {
        defaults.bool(forKey: proKey)
    }

    var remainingFreeImportsDescription: String {
        T("免费版最多可保存 \(freeScoreLimit) 首乐谱。", "The free version can store up to \(freeScoreLimit) scores.")
    }

    func canAddScore(currentCount: Int) -> Bool {
        isProUnlocked || currentCount < freeScoreLimit
    }

    func markProUnlockedForTesting(_ unlocked: Bool) {
        defaults.set(unlocked, forKey: proKey)
    }
}

enum EntitlementError: LocalizedError {
    case scoreLimitReached

    var errorDescription: String? {
        switch self {
        case .scoreLimitReached:
            T(
                "免费版最多保存 15 首乐谱。请升级 Pro 以解锁无限曲库、同步和团队功能。",
                "The free version stores up to 15 scores. Upgrade to Pro to unlock an unlimited library, sync, and team features."
            )
        }
    }
}
