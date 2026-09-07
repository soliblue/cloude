import Foundation
import SwiftData

enum GitMutationService {
    static func perform(
        _ action: String, session: Session, files: [String] = [], message: String = "",
        context: ModelContext
    ) async -> String? {
        if let endpoint = session.endpoint, let path = session.path,
            let (data, response) = await HTTPClient.post(
                endpoint: endpoint,
                path: "/sessions/\(session.id.uuidString)/git/mutate",
                body: ["path": path, "action": action, "files": files, "message": message],
                timeout: 40
            )
        {
            if response.statusCode == 200 {
                await GitService.refresh(session: session, context: context)
                return nil
            }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? "Your host could not complete this Git operation. Update the daemon and try again."
        }
        return "Could not confirm the result from your host. Refresh Git before trying again."
    }
}
