import Foundation

@MainActor
protocol FollowUpRepository {
    func fetch(id: UUID) throws -> FollowUp?
    func fetchList(filter: FollowUpListFilter) throws -> [FollowUpListItem]
    func fetchDetail(id: UUID) throws -> FollowUpDetail?
    func commit(_ mutation: FollowUpMutation) throws
}
