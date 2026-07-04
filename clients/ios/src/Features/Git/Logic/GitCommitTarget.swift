struct GitCommitTarget: Identifiable {
    let sha: String
    let subject: String
    var id: String { sha }
}
