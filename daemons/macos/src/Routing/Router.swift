import Foundation

enum Router {
    static func handle(_ request: HTTPRequest) -> HTTPResponse {
        if AuthMiddleware.isAuthorized(request) {
            if ["GET", "POST"].contains(request.method),
                let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/compact")
            {
                return CodexCompactionHandler.handle(request, params: params)
            }
            if ["GET", "POST", "DELETE"].contains(request.method),
                let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/goal")
            {
                return CodexHandler.goal(request, params: params)
            }
            if request.method == "PUT", request.path == "/push/device" { return PushHandler.register(request) }
            if request.method == "GET" {
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId/stream")
                {
                    return CodexTerminalHandler.stream(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals") {
                    return CodexTerminalHandler.list(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/branches") {
                    return GitHandler.branches(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/worktrees") {
                    return GitHandler.worktrees(request, params: params)
                }
                if request.path == "/codex/skills" { return CodexHandler.skills(request) }
                if request.path == "/codex/modes" { return CodexHandler.modes(request) }
                if request.path == "/codex/projects" { return CodexHandler.projects(request) }
                if request.path == "/codex/models" { return CodexHandler.models(request) }
                if request.path == "/codex/account" { return CodexHandler.account(request) }
                if request.path == "/codex/login" { return CodexHandler.login(request) }
                if request.path == "/codex/plugins" { return CodexPluginHandler.plugins(request) }
                if request.path == "/codex/plugin" { return CodexPluginHandler.plugin(request) }
                if request.path == "/codex/apps" { return CodexPluginHandler.apps(request) }
                if request.path == "/codex/mcp" { return CodexPluginHandler.mcp(request) }
                if request.path == "/codex/sections" { return CodexSectionHandler.sections(request) }
                if let params = RouteMatcher.match(request.path, pattern: "/codex/sections/:id/threads") {
                    return CodexSectionHandler.threads(request, params: params)
                }
                if request.path == "/codex/limits" { return CodexHandler.limits(request) }
                if request.path == "/codex/threads" { return CodexHandler.threads(request) }
                if let params = RouteMatcher.match(request.path, pattern: "/codex/threads/:id") {
                    return CodexHandler.history(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/history") {
                    return CodexHandler.history(request, params: params)
                }
                if request.path == "/ping" {
                    return PingHandler.handle(request)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/files") {
                    return FilesHandler.list(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/files/read") {
                    return FilesHandler.read(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/files/search") {
                    return FilesHandler.search(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/manifest") {
                    return SessionManifestHandler.manifest(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/resume") {
                    return ChatHandler.resume(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/requests") {
                    return ChatHandler.requests(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/status") {
                    return GitHandler.status(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/diff") {
                    return GitHandler.diff(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/log") {
                    return GitHandler.log(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/commit") {
                    return GitHandler.commit(request, params: params)
                }
            }
            if request.method == "POST" {
                if request.path == "/codex/attention" { return CodexAttentionHandler.batch(request) }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId/input") {
                    return CodexTerminalHandler.input(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId/resize")
                {
                    return CodexTerminalHandler.resize(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals") {
                    return CodexTerminalHandler.start(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/worktrees") {
                    return GitHandler.createWorktree(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/git/mutate") {
                    return GitHandler.mutate(request, params: params)
                }
                if request.path == "/codex/projects" { return CodexHandler.createProject(request) }
                if request.path == "/codex/login" { return CodexHandler.login(request) }
                if request.path == "/codex/plugin" { return CodexPluginHandler.plugin(request) }
                if request.path == "/codex/apps/read" { return CodexPluginHandler.readApps(request) }
                if request.path == "/codex/sections" { return CodexSectionHandler.sections(request) }
                if let params = RouteMatcher.match(request.path, pattern: "/codex/sections/:id/update") {
                    return CodexSectionHandler.update(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/section") {
                    return CodexSectionHandler.move(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/name") {
                    return CodexHandler.rename(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/fork") {
                    return CodexHandler.fork(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/import") {
                    return CodexHandler.importThread(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/archive") {
                    return CodexHandler.archive(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat") {
                    return ChatHandler.start(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/abort") {
                    return ChatHandler.abort(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/steer") {
                    return ChatHandler.steer(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/respond") {
                    return ChatHandler.respond(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/title") {
                    return SessionHandler.updateTitle(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/transcribe") {
                    return TranscribeHandler.transcribe(request, params: params)
                }
                if request.path == "/debug/ios-log" {
                    return DebugHandler.uploadIOSLog(request)
                }
            }
            if request.method == "DELETE", request.path == "/codex/login" { return CodexHandler.login(request) }
            if request.method == "DELETE",
                let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId")
            {
                return CodexTerminalHandler.terminate(request, params: params)
            }
            if request.method == "DELETE", request.path == "/codex/plugin" { return CodexPluginHandler.plugin(request) }
            if request.method == "DELETE", let params = RouteMatcher.match(request.path, pattern: "/codex/sections/:id")
            {
                return CodexSectionHandler.delete(request, params: params)
            }
            return HTTPResponse.json(404, ["error": "not_found"])
        }
        return HTTPResponse.json(401, ["error": "unauthorized"])
    }
}
