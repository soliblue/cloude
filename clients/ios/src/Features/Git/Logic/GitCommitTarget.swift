struct GitCommitTarget: Identifiable {
    let sha: String
    var id: String { sha }
}
