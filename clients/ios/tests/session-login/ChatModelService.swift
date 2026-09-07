import Foundation

@MainActor enum ChatModelService {
    static var refreshed: [UUID] = []
    static func refresh(session: Session) async { refreshed.append(session.id) }
}
