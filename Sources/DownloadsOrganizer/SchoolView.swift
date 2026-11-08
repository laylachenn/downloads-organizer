import SwiftUI

struct SchoolView: View {
    @EnvironmentObject private var store: Store
    @LocalState private var newSeason: Season = Semesters.current().season
    @LocalState private var newYear: Int = Semesters.current().year
    @LocalState private var showNew = false
    @LocalState private var extText = ""
    @LocalState private var archiving: [Semester] = []
    @LocalState private var confirmArchive = false
    @LocalState private var message: String?
    @LocalState private var problems: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(emoji: "🎓", title: "School",
                       subtitle: "A folder for every semester, and an Archive for the finished ones")

            if let message { Banner(emoji: "✨", text: message) }
            if !problems.isEmpty {
                Banner(emoji: "🥺", text: "A few things didn't move", detail: problems.joined(separator: "\n"), tint: .peach)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    currentCard
                    semestersCard
                    settingsCard
                }
                .padding(.bottom, 20)
            }
        }
        .padding(24)
        .onAppear {
            store.refreshSemesters()
            extText = store.schoolExtensions.joined(separator: ", ")
        }
        .confirmationDialog(archiveTitle, isPresented: $confirmArchive, titleVisibility: .visible) {
            Button("Move to Archive") { doArchive() }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("The whole folder moves into \(prettyPath(store.archive)) with the same name. Nothing inside is changed, renamed or deleted.")
        }
    }

    // MARK: Current semester

    private var currentCard: some View {
        let now = Semesters.current()
        let nowName = store.newSemesterName(now.season, now.year)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Current semester").font(rounded(.headline, .bold)).foregroundStyle(Theme.text)

            if let current = store.currentSemesterURL {
                HStack(spacing: 12) {
                    FileIcon(url: current, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.lastPathComponent)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.deepPink)
                        Text(prettyPath(current)).font(rounded(.caption)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([current]) }
                        .buttonStyle(CuteButtonStyle(prominent: false))
                }
            } else {
                Text("No current semester picked yet.").font(rounded(.callout)).foregroundStyle(.secondary)
            }

            if store.activeSemester(now.season, now.year) == nil {
                HStack {
                    Text("\(now.season.emoji) It's \(nowName) now!").font(rounded(.body, .semibold)).foregroundStyle(Theme.text)
                    Spacer()
                    Button("✨ Make “\(nowName)” folder") { create(now.season, now.year) }
                        .buttonStyle(CuteButtonStyle())
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Pastel.butter.color.opacity(0.55)))
            }

            HStack(spacing: 10) {
                if store.activeSemesters.count > 1 {
                    Menu {
                        ForEach(store.activeSemesters) { s in
                            Button("\(s.season.emoji) \(s.name)") { store.currentSemesterPath = s.url.path }
                        }
                    } label: {
                        Text("🔁 Switch semester").font(rounded(.body, .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.hotPink.opacity(0.12)))
                }
                Button("＋ Another semester…") { withAnimation { showNew.toggle() } }
                    .buttonStyle(CuteButtonStyle(prominent: false))
                Spacer()
            }

            if showNew {
                HStack(spacing: 10) {
                    Picker("", selection: $newSeason) {
                        ForEach(Season.allCases) { Text("\($0.emoji) \($0.rawValue.capitalized)").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    Stepper(value: $newYear, in: 2000...2100) {
                        Text(String(newYear)).font(rounded(.body, .semibold)).monospacedDigit()
                    }
                    Text("→ “\(store.newSemesterName(newSeason, newYear))” in \(prettyPath(store.school))")
                        .font(rounded(.caption)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Create") {
                        create(newSeason, newYear)
                        showNew = false
                    }
                    .buttonStyle(CuteButtonStyle())
                }
            }

            Divider()

            Toggle(isOn: $store.autoSort) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send new downloads straight to \(store.currentSemesterURL?.lastPathComponent ?? "your semester folder")")
                        .font(rounded(.body, .semibold)).foregroundStyle(Theme.text)
                    Text("School files you download from now on go right in. The app keeps running in the menu bar (🩷) so this works even with the window closed. Files keep their names and are never overwritten.")
                        .font(rounded(.caption)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .disabled(store.currentSemesterURL == nil)

            if store.autoSort && !store.recentAutoSorted.isEmpty {
                Text("Just sorted: " + store.recentAutoSorted.prefix(6).joined(separator: ", "))
                    .font(rounded(.caption)).foregroundStyle(Theme.text.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .cuteCard()
    }

    // MARK: Semester list

    private var finished: [Semester] { store.activeSemesters.filter { store.isFinished($0) } }

    private var semestersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your semesters").font(rounded(.headline, .bold)).foregroundStyle(Theme.text)
                Spacer()
                if !finished.isEmpty {
                    Button("📦 Archive \(plural(finished.count, "finished semester"))") {
                        archiving = finished
                        confirmArchive = true
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.deepPink))
                }
            }
            if store.semesters.isEmpty {
                Text("No semester folders found yet. I looked in your home folder, Desktop, Documents and Downloads.")
                    .font(rounded(.callout)).foregroundStyle(.secondary)
            }
            ForEach(store.activeSemesters) { semesterRow($0) }
            if !store.archivedSemesters.isEmpty {
                Text("📦 In the Archive").font(rounded(.subheadline, .bold)).foregroundStyle(Theme.text).padding(.top, 6)
                ForEach(store.archivedSemesters) { semesterRow($0) }
            }
        }
        .cuteCard()
    }

    private func semesterRow(_ s: Semester) -> some View {
        let archived = store.isArchived(s)
        let current = store.isCurrent(s)
        return HStack(spacing: 10) {
            FileIcon(url: s.url, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.season.emoji) \(s.name)").font(rounded(.callout, .semibold)).foregroundStyle(Theme.text)
                Text("\(prettyPath(s.url.deletingLastPathComponent())) · \(plural(FileOps.itemCount(in: s.url), "item"))")
                    .font(rounded(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            if current { tag("current", .mint) }
            else if archived { tag("archived", .sky) }
            else if store.isFinished(s) { tag("finished", .butter) }

            if !archived && !current {
                Button("Make current") { store.currentSemesterPath = s.url.path }
                    .buttonStyle(.borderless).font(rounded(.caption, .semibold))
            }
            if !archived && store.isFinished(s) {
                Button("Archive") {
                    archiving = [s]
                    confirmArchive = true
                }
                .buttonStyle(.borderless).font(rounded(.caption, .semibold))
            }
            RevealButton(url: s.url)
        }
        .padding(.vertical, 2)
    }

    private func tag(_ text: String, _ color: Pastel) -> some View {
        Text(text)
            .font(rounded(.caption2, .bold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.color))
    }

    // MARK: Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(rounded(.headline, .bold)).foregroundStyle(Theme.text)
            pathRow("New semester folders go in", store.school) {
                if let url = pickFolder(start: store.school, prompt: "Use this folder") { store.schoolPath = url.path }
            }
            pathRow("Archive folder", store.archive) {
                if let url = pickFolder(start: store.archive.deletingLastPathComponent(), prompt: "Use as Archive") {
                    store.archivePath = url.path
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("School file types").font(rounded(.callout, .semibold)).foregroundStyle(Theme.text)
                TextField("", text: $extText, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("These go into your semester folder when you tidy up or auto-sort.")
                        .font(rounded(.caption)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Save") { store.schoolExtensions = FolderCategory.parseExtensions(extText) }
                        .buttonStyle(CuteButtonStyle(prominent: false))
                        .disabled(FolderCategory.parseExtensions(extText) == store.schoolExtensions)
                }
            }
        }
        .cuteCard()
    }

    private func pathRow(_ label: String, _ url: URL, change: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(rounded(.callout, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Text(prettyPath(url)).font(rounded(.callout)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            Button("Change…", action: change).buttonStyle(.borderless).font(rounded(.callout, .semibold))
        }
    }

    // MARK: Actions

    private var archiveTitle: String {
        archiving.count == 1
            ? "Move “\(archiving.first?.name ?? "")” into Archive?"
            : "Move \(archiving.count) semesters into Archive?"
    }

    private func create(_ season: Season, _ year: Int) {
        do {
            try store.createSemester(season, year)
            problems = []
            message = "“\(store.currentSemesterURL?.lastPathComponent ?? "")” is your current semester 🎓"
        } catch {
            problems = ["Couldn't make the folder: \(error.localizedDescription)"]
        }
    }

    private func doArchive() {
        let names = archiving.map(\.name)
        problems = archiving.compactMap { store.archiveSemester($0) }
        let moved = names.count - problems.count
        message = moved > 0 ? "Moved \(plural(moved, "semester")) into the Archive 📦" : nil
        archiving = []
    }
}
