import Foundation

final class TeamSharingService {
    private let repository: ScoreRepository
    private var teams: [TeamWorkspace] = []

    init(repository: ScoreRepository) {
        self.repository = repository
    }

    func createTeam(named name: String, ownerName: String, ownerEmail: String) -> TeamWorkspace {
        let team = TeamWorkspace(
            id: UUID(),
            name: name,
            members: [
                TeamWorkspace.Member(
                    id: UUID(),
                    displayName: ownerName,
                    email: ownerEmail,
                    role: .owner
                )
            ],
            sharedSetlistIDs: [],
            updatedAt: Date()
        )
        teams.insert(team, at: 0)
        return team
    }

    func shareSetlist(_ setlist: PerformanceSetlist, with team: TeamWorkspace) -> TeamWorkspace {
        var updated = team
        if !updated.sharedSetlistIDs.contains(setlist.id) {
            updated.sharedSetlistIDs.append(setlist.id)
            updated.updatedAt = Date()
        }
        teams.removeAll { $0.id == updated.id }
        teams.insert(updated, at: 0)
        return updated
    }

    func availableTeams() -> [TeamWorkspace] {
        teams
    }
}
