import Foundation

struct PerformanceSetlist: Codable, Identifiable {
    let id: UUID
    var name: String
    var scoreIDs: [UUID]
    var updatedAt: Date
}
