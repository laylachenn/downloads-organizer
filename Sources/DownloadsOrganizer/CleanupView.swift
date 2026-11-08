import SwiftUI

enum KindFilter: String, CaseIterable, Identifiable {
    case all, installers, zips, pictures, videos, documents

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "Everything"
        case .installers: "💿 Installers"
        case .zips: "📦 Zips"
        case .pictures: "🌸 Pictures"
        case .videos: "🎬 Videos"
        case .documents: "📄 Documents"
        }
    }
    var extensions: Set<String>? {
        switch self {
        case .all: nil
        case .installers: ["dmg", "pkg", "mpkg", "app", "iso", "exe", "msi"]
        case .zips: ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]
        case .pictures: ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "svg"]
        case .videos: ["mov", "mp4", "m4v", "avi", "mkv", "webm", "wmv"]
        case .documents: ["pdf", "doc", "docx", "txt", "rtf", "pages", "csv", "xls", "xlsx", "numbers", "ppt", "pptx", "key"]
        }
    }
    func includes(_ url: URL) -> Bool { extensions?.contains(url.pathExtension.lowercased()) ?? true }
}

struct CleanupView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("cleanupDays") private var days = 30
    @LocalState private var kind: KindFilter = .all
    @LocalState private var folder: URL = Paths.downloads
    @LocalState private var items: [OldItem] = []
    @LocalState private var installers: [OldItem] = []
    @LocalState private var selected: Set<URL> = []
    @LocalState private var confirming = false
    @LocalState private var message: (text: String, detail: String?)?
    @LocalState private var scanned = false

    private var selectedItems: [OldItem] { items.filter { selected.contains($0.url) } }
    private var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(emoji: "🧹", title: "Clean Out",
                       subtitle: "Toss old stuff and installers you don't need anymore")

            if kind != .installers && !installers.isEmpty { installerNudge }

            HStack(spacing: 10) {
                Picker("", selection: $days) {
                    Text("Any age").tag(0)
                    Text("Older than 1 week").tag(7)
                    Text("Older than 2 weeks").tag(14)
                    Text("Older than 1 month").tag(30)
                    Text("Older than 3 months").tag(90)
                    Text("Older than 6 months").tag(180)
                    Text("Older than 1 year").tag(365)
                }
                .labelsHidden()
                .frame(width: 170)
                Text("in").font(rounded(.body, .medium)).foregroundStyle(Theme.text)
                folderMenu
                Spacer()
                Button("🔍 Look again") { scan() }
                    .buttonStyle(CuteButtonStyle(prominent: false))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(KindFilter.allCases) { k in
                        Button(k.label) { kind = k }
                            .buttonStyle(CuteButtonStyle(prominent: kind == k))
                    }
                }
            }

            if let message {
                Banner(emoji: "🗑️", text: message.text, detail: message.detail)
            }

            if !scanned {
                EmptyHint(emoji: "🧺", text: "Looking…")
            } else if items.isEmpty {
                EmptyHint(emoji: "🌸", text: "Nothing like that in \(folder.lastPathComponent). So fresh!")
            } else {
                HStack {
                    Button(selected.count == items.count ? "Unselect all" : "Select all") {
                        selected = selected.count == items.count ? [] : Set(items.map(\.url))
                    }
                    .buttonStyle(.borderless)
                    .font(rounded(.callout, .semibold))
                    Spacer()
                    Text("\(plural(items.count, "item")) · \(prettySize(totalSize))")
                        .font(rounded(.callout)).foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(items) { row($0) }
                    }
                    .cuteCard()
                    .padding(.bottom, 8)
                }

                HStack {
                    Text("Things go to the Trash, so you can still get them back 💕")
                        .font(rounded(.caption)).foregroundStyle(.secondary)
                    Spacer()
                    Button("🗑️ Move \(plural(selected.count, "item")) to Trash · \(prettySize(selectedSize))") {
                        confirming = true
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.deepPink))
                    .disabled(selected.isEmpty)
                }
            }
        }
        .padding(24)
        .onAppear { if !scanned { scan() } }
        .onChange(of: days) { scan() }
        .onChange(of: kind) { scan() }
        .confirmationDialog("Move \(plural(selected.count, "item")) to the Trash?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { trash() }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("That's \(prettySize(selectedSize)). They'll wait in the Trash until you empty it, so you can still change your mind.")
        }
    }

    private var installerNudge: some View {
        let size = installers.reduce(Int64(0)) { $0 + $1.size }
        return HStack(spacing: 12) {
            Text("💿").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(plural(installers.count, "installer")) hanging out in \(folder.lastPathComponent) · \(prettySize(size))")
                    .font(rounded(.body, .semibold)).foregroundStyle(Theme.text)
                Text("Once an app is installed you don't need its .dmg or .pkg anymore.")
                    .font(rounded(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Pick them all") {
                kind = .installers
                days = 0
                scan()
                selected = Set(items.map(\.url))
            }
            .buttonStyle(CuteButtonStyle())
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Pastel.butter.color.opacity(0.55)))
    }

    private var folderMenu: some View {
        Menu {
            Button("📥 Downloads") { choose(Paths.downloads) }
            if let current = store.currentSemesterURL {
                Button("🎓 \(current.lastPathComponent)") { choose(current) }
            }
            if FileManager.default.fileExists(atPath: store.archivePath) {
                Button("📦 Archive") { choose(store.archive) }
            }
            let existing = store.categories.filter { FileManager.default.fileExists(atPath: $0.destinationPath) }
            if !existing.isEmpty {
                Divider()
                ForEach(existing) { c in
                    Button("\(c.emoji) \(c.name)") { choose(c.destination) }
                }
            }
            Divider()
            Button("Other folder…") {
                if let url = pickFolder(start: folder, prompt: "Look here") { choose(url) }
            }
        } label: {
            Text("📂 \(folder.lastPathComponent)").font(rounded(.body, .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Theme.hotPink.opacity(0.12)))
    }

    private func row(_ item: OldItem) -> some View {
        let isOn = selected.contains(item.url)
        return HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.hotPink : Color.gray.opacity(0.5))
                FileIcon(url: item.url, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.url.lastPathComponent)
                        .font(rounded(.callout)).lineLimit(1).truncationMode(.middle)
                    Text("added \(item.added.formatted(.relative(presentation: .named)))")
                        .font(rounded(.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(prettySize(item.size)).font(rounded(.caption, .medium)).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isOn { selected.remove(item.url) } else { selected.insert(item.url) }
            }
            RevealButton(url: item.url)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isOn ? Pastel.pink.color.opacity(0.25) : Color.clear))
    }

    private func choose(_ url: URL) {
        folder = url
        scan()
    }

    private func scan() {
        let everything = FileOps.oldItems(in: folder, olderThanDays: 0)
        installers = everything.filter { KindFilter.installers.includes($0.url) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        items = everything.filter { (days == 0 || $0.added < cutoff) && kind.includes($0.url) }
        selected = selected.intersection(Set(items.map(\.url)))
        scanned = true
    }

    private func trash() {
        let result = FileOps.moveToTrash(selectedItems.map(\.url))
        message = (
            "Moved \(plural(result.trashed, "item")) to the Trash ✨",
            result.failed.isEmpty ? nil : "Couldn't move: " + result.failed.joined(separator: ", ")
        )
        selected = []
        scan()
    }
}
