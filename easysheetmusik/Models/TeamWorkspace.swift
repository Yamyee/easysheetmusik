import Foundation

struct TeamWorkspace: Codable, Identifiable {
    enum Role: String, Codable {
        case owner
        case editor
        case viewer
    }

    struct Member: Codable, Identifiable {
        let id: UUID
        var displayName: String
        var email: String
        var role: Role
    }

    let id: UUID
    var name: String
    var members: [Member]
    var sharedSetlistIDs: [UUID]
    var updatedAt: Date
}
