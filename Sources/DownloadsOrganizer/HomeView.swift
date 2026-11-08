import SwiftUI
import QuickLookThumbnailing

/// Home: a friendlier Finder. Shows places (fall 2026 first) or browses inside a folder.
struct HomeView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        if let folder = store.browseStack.last {
            BrowserView(folder: folder).id(folder)
        } else {
            PlacesView()
        }
    }
}

// MARK: - Places

struct Place: Identifiable {
    let url: URL
    let label: String
    var id: String { url.path }
}

struct PlacesView: View {
    @EnvironmentObject private var store: Store
    @LocalState private var recent: [URL] = []

    private var sortedFolders: [Place] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: Paths.sorted, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey], options: [.skipsHiddenFiles])) ?? []
        return items
            .filter { url in
                let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                return v?.isDirectory == true && v?.isPackage != true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { Place(url: $0, label: $0.lastPathComponent) }
    }

    private var morePlaces: [Place] {
        let home = Paths.home
        return [
            Place(url: Paths.downloads, label: "Downloads"),
            Place(url: Paths.documents, label: "Documents folder"),
            Place(url: store.archive, label: "Archive"),
            Place(url: home.appendingPathComponent("personal-projects"), label: "Projects"),
            Place(url: home.appendingPathComponent("Pictures"), label: "Pictures folder"),
        ]
        .filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(emoji: "🏠", title: "Home", subtitle: "All your folders in one cute place")
                if let semester = store.currentSemesterURL {
                    semesterHero(semester)
                } else {
                    Banner(emoji: "🎓", text: "No current semester yet. Make one on the School page!", tint: .butter)
                }
                section("Your folders", sortedFolders)
                section("More places", morePlaces)
            }
            .padding(24)
        }
        .onAppear(perform: loadRecent)
    }

    private func semesterHero(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                FileIcon(url: url, size: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎓 \(url.lastPathComponent)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.deepPink)
                    Text("\(plural(FileOps.itemCount(in: url), "item")) · \(prettyPath(url))")
                        .font(rounded(.callout)).foregroundStyle(Theme.text.opacity(0.7))
                }
                Spacer()
                Button("Open 💖") { store.browse(url) }
                    .buttonStyle(CuteButtonStyle())
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path) }
                    .buttonStyle(CuteButtonStyle(prominent: false))
            }
            if !recent.isEmpty {
                Text("Recently added").font(rounded(.subheadline, .bold)).foregroundStyle(Theme.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recent, id: \.self) { file in
                            Tile(url: file, selected: false, onOpen: { open(file) }, onSelect: {})
                                .contextMenu {
                                    Button("Open") { open(file) }
                                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                                }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Pastel.lavender.color.opacity(0.55), Pastel.pink.color.opacity(0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: Theme.hotPink.opacity(0.15), radius: 12, y: 5)
    }

    private func section(_ title: String, _ places: [Place]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(rounded(.headline, .bold)).foregroundStyle(Theme.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
                ForEach(places) { place in
                    Button { store.browse(place.url) } label: {
                        VStack(spacing: 6) {
                            FileIcon(url: place.url, size: 72)
                            Text(place.label).font(rounded(.callout, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(plural(FileOps.itemCount(in: place.url), "item"))
                                .font(rounded(.caption)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.85)))
                        .shadow(color: Theme.hotPink.opacity(0.1), radius: 8, y: 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open") { store.browse(place.url) }
                        Button("Show in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: place.url.path) }
                    }
                }
            }
        }
    }

    private func loadRecent() {
        guard let semester = store.currentSemesterURL else { recent = []; return }
        recent = BrowserItem.load(semester)
            .sorted { $0.added > $1.added }
            .prefix(8)
            .map(\.url)
    }

    private func open(_ url: URL) {
        if BrowserItem.isFolder(url) { store.browseStack = [store.currentSemesterURL ?? url, url].uniqued() }
        else { NSWorkspace.shared.open(url) }
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen = Set<String>()
        return filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

extension Store {
    /// Folders you can move things into, current semester first.
    var movePlaces: [Place] {
        var places: [Place] = activeSemesters.map { Place(url: $0.url, label: "🎓 \($0.name)") }
        let fm = FileManager.default
        let sortedItems = (try? fm.contentsOfDirectory(at: Paths.sorted, includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles])) ?? []
        places += sortedItems.filter { BrowserItem.isFolder($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { Place(url: $0, label: "📁 \($0.lastPathComponent)") }
        places += [
            Place(url: archive, label: "📦 Archive"),
            Place(url: Paths.home.appendingPathComponent("personal-projects"), label: "💻 Projects"),
            Place(url: Paths.documents, label: "🗂️ Documents folder"),
            Place(url: Paths.downloads, label: "📥 Downloads"),
        ].filter { fm.fileExists(atPath: $0.url.path) }
        return places
    }
}

// MARK: - Browser

struct BrowserItem: Identifiable, Hashable {
    let url: URL
    let isFolder: Bool
    let added: Date
    let modified: Date
    var id: URL { url }

    static func isFolder(_ url: URL) -> Bool {
        let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return v?.isDirectory == true && v?.isPackage != true
    }

    static func load(_ folder: URL) -> [BrowserItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .addedToDirectoryDateKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return urls.compactMap { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            let modified = v?.contentModificationDate ?? .distantPast
            return BrowserItem(url: url,
                               isFolder: v?.isDirectory == true && v?.isPackage != true,
                               added: v?.addedToDirectoryDate ?? modified,
                               modified: modified)
        }
    }
}

struct BrowserView: View {
    @EnvironmentObject private var store: Store
    let folder: URL

    @LocalState private var items: [BrowserItem] = []
    @LocalState private var search = ""
    @AppStorage("browserSort") private var sort = "name"
    @LocalState private var selection: Set<URL> = []
    @LocalState private var anchor: URL?
    @LocalState private var lastMove: [(from: URL, to: URL)] = []
    @LocalState private var folderStamp: Date?
    @LocalState private var note: (emoji: String, text: String)?

    private let ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var shown: [BrowserItem] {
        let filtered = search.isEmpty ? items
            : items.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(search) }
        return filtered.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            switch sort {
            case "newest": return a.added > b.added
            default: return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar
            if let note {
                HStack(alignment: .center) {
                    Banner(emoji: note.emoji, text: note.text)
                    if !lastMove.isEmpty {
                        Button("↩︎ Undo") { undoMove() }
                            .buttonStyle(CuteButtonStyle(prominent: false))
                    }
                }
            }
            if shown.isEmpty {
                EmptyHint(emoji: search.isEmpty ? "🫧" : "🔍",
                          text: search.isEmpty ? "This folder is empty" : "Nothing called “\(search)” here")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 10) {
                        ForEach(shown) { item in
                            Tile(url: item.url, selected: selection.contains(item.url),
                                 showCheck: !selection.isEmpty,
                                 onOpen: { open(item) }, onSelect: { click(item) },
                                 onToggle: { toggle(item.url) })
                                .contextMenu { menu(for: item) }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .cuteCard()
            }
            if selection.isEmpty {
                Text("Click the circle on a file to select it (or ⌘-click / ⇧-click / ⌘A) · double-click to open · drag files out to upload them 💌")
                    .font(rounded(.caption)).foregroundStyle(.secondary)
            } else {
                moveBar
            }
        }
        .background {
            // keyboard shortcuts
            Button("") { selection = Set(shown.map(\.url)) }.keyboardShortcut("a", modifiers: .command).hidden()
            Button("") { selection = [] }.keyboardShortcut(.escape, modifiers: []).hidden()
        }
        .padding(24)
        .onAppear(perform: load)
        .onReceive(ticker) { _ in reloadIfChanged() }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { store.browseStack.removeLast() } label: {
                Image(systemName: "chevron.left").font(.body.weight(.bold))
            }
            .buttonStyle(CuteButtonStyle(prominent: false))
            .keyboardShortcut("[", modifiers: .command)
            .help("Back")

            Button { store.browseStack = [] } label: { Image(systemName: "house.fill") }
                .buttonStyle(CuteButtonStyle(prominent: false))
                .help("Home")

            // breadcrumb
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(store.browseStack.enumerated()), id: \.offset) { i, url in
                        if i > 0 { Text("›").foregroundStyle(.secondary) }
                        Button(url.lastPathComponent) { store.browseStack = Array(store.browseStack.prefix(i + 1)) }
                            .buttonStyle(.borderless)
                            .font(rounded(i == store.browseStack.count - 1 ? .title3 : .body, .bold))
                            .foregroundStyle(i == store.browseStack.count - 1 ? Theme.deepPink : Theme.text)
                    }
                }
            }

            Spacer(minLength: 8)

            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
            Picker("", selection: $sort) {
                Text("A–Z").tag("name")
                Text("Newest").tag("newest")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 130)
            Button { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path) } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(CuteButtonStyle(prominent: false))
            .help("Open this folder in Finder")
        }
    }

    @ViewBuilder
    private func menu(for item: BrowserItem) -> some View {
        Button("Open") { open(item) }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        let targets = selection.contains(item.url) ? selectedURLs : [item.url]
        Divider()
        if let semester = store.currentSemesterURL, !Paths.same(folder, semester), !Paths.same(item.url, semester) {
            Button("🎓 Move \(targets.count > 1 ? "\(targets.count) items" : "") to \(semester.lastPathComponent)") {
                move(targets, to: semester)
            }
        }
        Menu("📂 Move to…") { moveMenuItems(targets) }
    }

    private func open(_ item: BrowserItem) {
        if item.isFolder { store.browseStack.append(item.url) }
        else { NSWorkspace.shared.open(item.url) }
    }

    private var selectedURLs: [URL] { shown.map(\.url).filter { selection.contains($0) } }

    private var moveBar: some View {
        HStack(spacing: 10) {
            Text("✅ \(plural(selection.count, "item")) selected")
                .font(rounded(.body, .semibold)).foregroundStyle(Theme.text)
            Button("Clear") { selection = [] }
                .buttonStyle(.borderless).font(rounded(.callout, .semibold))
            Spacer()
            if let semester = store.currentSemesterURL, !Paths.same(folder, semester) {
                Button("🎓 Move to \(semester.lastPathComponent)") { move(selectedURLs, to: semester) }
                    .buttonStyle(CuteButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
            }
            Menu { moveMenuItems(selectedURLs) } label: {
                Text("📂 Move to…").font(rounded(.body, .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(Theme.hotPink.opacity(0.12)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.95)))
        .shadow(color: Theme.hotPink.opacity(0.15), radius: 10, y: 3)
    }

    @ViewBuilder
    private func moveMenuItems(_ urls: [URL]) -> some View {
        let here = shown.filter { $0.isFolder && !urls.contains($0.url) }
        if !here.isEmpty {
            Section("Folders in \(folder.lastPathComponent)") {
                ForEach(here) { f in Button("📁 \(f.url.lastPathComponent)") { move(urls, to: f.url) } }
            }
        }
        Section("Places") {
            ForEach(store.movePlaces.filter { !Paths.same($0.url, folder) }) { place in
                Button(place.label) { move(urls, to: place.url) }
            }
        }
        Divider()
        Button("Choose a folder…") {
            if let url = pickFolder(start: folder, prompt: "Move here") { move(urls, to: url) }
        }
    }

    private func click(_ item: BrowserItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            toggle(item.url)
        } else if flags.contains(.shift), let anchor,
                  let a = shown.firstIndex(where: { $0.url == anchor }),
                  let b = shown.firstIndex(where: { $0.url == item.url }) {
            selection.formUnion(shown[min(a, b)...max(a, b)].map(\.url))
        } else {
            selection = [item.url]
            anchor = item.url
        }
    }

    private func toggle(_ url: URL) {
        if selection.contains(url) { selection.remove(url) } else { selection.insert(url) }
        anchor = url
    }

    /// Moves keep the exact name and never overwrite (see FileOps.moveItems). Undo puts them back.
    private func move(_ urls: [URL], to destination: URL) {
        guard !urls.isEmpty else { return }
        let result = FileOps.moveItems(urls, into: destination)
        lastMove = result.moved
        var text = result.moved.isEmpty ? "Nothing moved" : "Moved \(plural(result.moved.count, "item")) to \(destination.lastPathComponent)"
        if !result.skipped.isEmpty {
            text += ". \(plural(result.skipped.count, "item")) stayed put (same name already there): " + result.skipped.joined(separator: ", ")
        }
        if !result.failed.isEmpty { text += ". Couldn't move: " + result.failed.joined(separator: ", ") }
        note = (result.moved.isEmpty ? "🥺" : "✨", text)
        selection = []
        load()
    }

    private func undoMove() {
        var back = 0
        for m in lastMove.reversed() where !FileManager.default.fileExists(atPath: m.from.path) {
            if (try? FileManager.default.moveItem(at: m.to, to: m.from)) != nil { back += 1 }
        }
        note = ("↩︎", "Put \(plural(back, "item")) back")
        lastMove = []
        load()
    }

    private func load() {
        items = BrowserItem.load(folder)
        folderStamp = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func reloadIfChanged() {
        var url = folder
        url.removeAllCachedResourceValues()
        let stamp = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if stamp != folderStamp { load() }
    }
}

// MARK: - Tiles & thumbnails

struct Tile: View {
    let url: URL
    var selected: Bool
    var showCheck = false
    var onOpen: () -> Void
    var onSelect: () -> Void
    var onToggle: (() -> Void)? = nil
    @LocalState private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Thumbnail(url: url, size: 72)
            Text(url.lastPathComponent)
                .font(rounded(.caption, .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30, alignment: .top)
        }
        .padding(8)
        .frame(width: 112)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(selected ? Theme.hotPink.opacity(0.18) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .simultaneousGesture(TapGesture().onEnded(onSelect))
        .overlay(alignment: .topLeading) {
            if let onToggle, showCheck || hovering || selected {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.hotPink : Color.gray.opacity(0.6))
                    .background(Circle().fill(.white).padding(2))
                    .padding(6)
                    .contentShape(Circle())
                    .onTapGesture(perform: onToggle)
            }
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .help(url.lastPathComponent)
    }
}

struct Thumbnail: View {
    let url: URL
    let size: CGFloat
    @LocalState private var image: NSImage?

    var body: some View {
        Image(nsImage: image ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .task(id: url) { image = await ThumbnailCache.thumbnail(for: url, size: size) }
    }
}

enum ThumbnailCache {
    private static let cache = NSCache<NSURL, NSImage>()

    /// A preview of the file's contents (PDF page, photo…). Folders keep their Finder icon, so buddy icons show.
    static func thumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { return nil }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size),
                                                   scale: 2, representationTypes: .thumbnail)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else { return nil }
        cache.setObject(rep.nsImage, forKey: url as NSURL)
        return rep.nsImage
    }
}
