import SwiftUI

struct TidyView: View {
    @EnvironmentObject private var store: Store
    @LocalState private var moves: [PlannedMove] = []
    @LocalState private var unmatched: [URL] = []
    @LocalState private var report: MoveReport?
    @LocalState private var scanned = false

    private var ready: [PlannedMove] { moves.filter { !$0.conflict } }
    private var groups: [FolderCategory] {
        store.sortingRules.filter { c in moves.contains { $0.category.id == c.id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(emoji: "✨", title: "Tidy Up",
                       subtitle: "Sort everything in \(store.source.lastPathComponent) into cute little folders")

            HStack(spacing: 10) {
                Button("🔍 Look again") { scan() }
                    .buttonStyle(CuteButtonStyle(prominent: false))
                Button("📂 \(store.source.lastPathComponent)…") {
                    if let url = pickFolder(start: store.source, prompt: "Tidy this folder") {
                        store.sourcePath = url.path
                        scan()
                    }
                }
                .buttonStyle(CuteButtonStyle(prominent: false))
                .help("Pick which folder to tidy")
                Spacer()
                Button("💖 Tidy \(plural(ready.count, "item"))") { tidy() }
                    .buttonStyle(CuteButtonStyle(color: Theme.deepPink))
                    .disabled(ready.isEmpty)
            }

            if let report { reportBanner(report) }

            if !scanned {
                EmptyHint(emoji: "🧺", text: "Peeking in your folder…")
            } else if moves.isEmpty && unmatched.isEmpty {
                EmptyHint(emoji: "🌷", text: "All tidy! Nothing to sort right now.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if !moves.isEmpty {
                            Text("Here's the plan. Nothing moves until you tap Tidy 💕")
                                .font(rounded(.callout))
                                .foregroundStyle(Theme.text.opacity(0.7))
                        }
                        ForEach(groups) { groupCard($0) }
                        if !unmatched.isEmpty { unmatchedCard }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(24)
        .onAppear { if !scanned { scan() } }
        .onChange(of: store.categories) { scan() }
        .onChange(of: store.currentSemesterPath) { scan() }
        .onChange(of: store.schoolExtensions) { scan() }
    }

    private func groupCard(_ category: FolderCategory) -> some View {
        let items = moves.filter { $0.category.id == category.id }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(category.emoji).font(.title2)
                Text(category.name).font(rounded(.headline, .bold)).foregroundStyle(Theme.text)
                Text("\(items.count)")
                    .font(rounded(.caption, .bold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(category.color.color))
                Spacer()
                Text("→ \(prettyPath(category.destination))")
                    .font(rounded(.caption)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            ForEach(items) { move in
                HStack(spacing: 10) {
                    FileIcon(url: move.source)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(move.source.lastPathComponent)
                            .font(rounded(.callout)).lineLimit(1).truncationMode(.middle)
                        if move.conflict {
                            Text("A file with this name is already in \(category.name), so this one stays put")
                                .font(rounded(.caption)).foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    RevealButton(url: move.source)
                }
                .opacity(move.conflict ? 0.6 : 1)
            }
        }
        .cuteCard()
    }

    private var unmatchedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("🤍").font(.title2)
                Text("Staying put").font(rounded(.headline, .bold)).foregroundStyle(Theme.text)
                Text("\(unmatched.count)")
                    .font(rounded(.caption, .bold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Color.gray.opacity(0.2)))
                Spacer()
            }
            Text("These don't match any folder yet. Add their file type in My Folders if you want them sorted.")
                .font(rounded(.caption)).foregroundStyle(.secondary)
            ForEach(unmatched, id: \.self) { url in
                HStack(spacing: 10) {
                    FileIcon(url: url)
                    Text(url.lastPathComponent).font(rounded(.callout)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    RevealButton(url: url)
                }
            }
        }
        .cuteCard()
    }

    private func reportBanner(_ report: MoveReport) -> some View {
        var details: [String] = []
        if !report.skipped.isEmpty {
            details.append("Skipped \(plural(report.skipped.count, "file")) (same name already there): " + report.skipped.joined(separator: ", "))
        }
        if !report.failed.isEmpty {
            details.append("Couldn't move: " + report.failed.map { "\($0.name) (\($0.reason))" }.joined(separator: "; "))
        }
        let title = report.moved.isEmpty ? "Nothing was moved" : "Tidied \(plural(report.moved.count, "item"))! 🎉"
        return Banner(emoji: report.failed.isEmpty ? "🌈" : "🥺", text: title,
                      detail: details.isEmpty ? nil : details.joined(separator: "\n"),
                      tint: report.failed.isEmpty ? .mint : .peach)
    }

    private func scan() {
        let result = FileOps.plan(source: store.source, categories: store.sortingRules)
        moves = result.moves
        unmatched = result.unmatched
        scanned = true
    }

    private func tidy() {
        report = FileOps.execute(ready)
        scan()
    }
}
