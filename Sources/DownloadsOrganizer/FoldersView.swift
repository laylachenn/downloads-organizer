import SwiftUI
import UniformTypeIdentifiers

struct EditRequest: Identifiable {
    let id = UUID()
    let category: FolderCategory
    let isNew: Bool
}

struct FoldersView: View {
    @EnvironmentObject private var store: Store
    @LocalState private var editing: EditRequest?
    @LocalState private var refresh = UUID()
    @LocalState private var problem: String?

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(emoji: "🎀", title: "My Folders",
                       subtitle: "Where things go, and their cute little icons")

            HStack {
                Button("✨ Create missing folders") { createMissing() }
                    .buttonStyle(CuteButtonStyle(prominent: false))
                    .disabled(missing.isEmpty)
                Spacer()
                Button("＋ New folder") {
                    let draft = FolderCategory(name: "", emoji: "💗", color: .pink, extensions: [],
                                               destinationPath: Paths.sortedFolder(named: "").path)
                    editing = EditRequest(category: draft, isNew: true)
                }
                .buttonStyle(CuteButtonStyle())
            }

            if let problem { Banner(emoji: "🥺", text: problem, tint: .peach) }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.categories) { category in
                        FolderCard(category: category,
                                   onEdit: { editing = EditRequest(category: category, isNew: false) },
                                   onCreate: { create(category) },
                                   onIcon: { image in setIcon(image, for: category) })
                    }
                }
                .id(refresh)
                .padding(.bottom, 20)
            }
        }
        .padding(24)
        .sheet(item: $editing) { request in
            EditFolderSheet(category: request.category, isNew: request.isNew,
                            onSave: { store.upsert($0); refresh = UUID() },
                            onRemove: request.isNew ? nil : { store.remove($0) })
        }
    }

    private var missing: [FolderCategory] {
        store.categories.filter { !FileManager.default.fileExists(atPath: $0.destinationPath) }
    }

    private func createMissing() {
        missing.forEach(create)
    }

    /// Makes the folder (if it doesn't exist) and gives it a cute icon.
    private func create(_ category: FolderCategory) {
        do {
            try FileManager.default.createDirectory(at: category.destination, withIntermediateDirectories: true)
            IconMaker.setIcon(IconMaker.folderIcon(emoji: category.emoji, color: category.color.nsColor),
                              forFolder: category.destination)
            problem = nil
        } catch {
            problem = "Couldn't create \(category.name): \(error.localizedDescription)"
        }
        refresh = UUID()
    }

    private func setIcon(_ image: NSImage?, for category: FolderCategory) {
        if !IconMaker.setIcon(image, forFolder: category.destination) {
            problem = "Couldn't change the icon for \(category.name). Check the app has permission to that folder."
        } else {
            problem = nil
        }
        refresh = UUID()
    }
}

struct FolderCard: View {
    let category: FolderCategory
    var onEdit: () -> Void
    var onCreate: () -> Void
    var onIcon: (NSImage?) -> Void

    private var exists: Bool { FileManager.default.fileExists(atPath: category.destinationPath) }

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if exists {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: category.destinationPath)).resizable()
                } else {
                    Image(nsImage: IconMaker.folderIcon(emoji: category.emoji, color: category.color.nsColor))
                        .resizable().opacity(0.45)
                }
            }
            .frame(width: 96, height: 96)

            Text("\(category.emoji) \(category.name)")
                .font(rounded(.headline, .bold)).foregroundStyle(Theme.text)
            Text(prettyPath(category.destination))
                .font(rounded(.caption)).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Text(category.extensions.isEmpty ? "no file types yet"
                 : category.extensions.prefix(7).map { ".\($0)" }.joined(separator: " ")
                   + (category.extensions.count > 7 ? " …" : ""))
                .font(rounded(.caption2)).foregroundStyle(Theme.text.opacity(0.6))
                .lineLimit(2).multilineTextAlignment(.center)

            if exists {
                iconMenu
            } else {
                Button("✨ Create folder") { onCreate() }
                    .buttonStyle(CuteButtonStyle())
            }

            HStack(spacing: 14) {
                Button("Edit") { onEdit() }
                if exists {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([category.destination])
                    }
                }
            }
            .buttonStyle(.borderless)
            .font(rounded(.caption, .semibold))
            .foregroundStyle(Theme.hotPink)
        }
        .frame(maxWidth: .infinity)
        .cuteCard()
    }

    private var iconMenu: some View {
        Menu {
            Button("\(category.emoji) Cute \(category.color.label.lowercased()) folder") {
                onIcon(IconMaker.folderIcon(emoji: category.emoji, color: category.color.nsColor))
            }
            Menu("Mochi buddy") {
                ForEach(Buddy.allCases) { b in
                    Button(b.label) { onIcon(IconMaker.buddyIcon(b, color: category.color.nsColor)) }
                }
            }
            Menu("Other colors") {
                ForEach(Pastel.allCases) { p in
                    Button(p.label) { onIcon(IconMaker.folderIcon(emoji: category.emoji, color: p.nsColor)) }
                }
            }
            Button("Choose a picture…") {
                if let image = pickImage() { onIcon(image) }
            }
            Divider()
            Button("Back to the normal folder icon") { onIcon(nil) }
        } label: {
            Text("🎨 Change icon").font(rounded(.body, .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Capsule().fill(Theme.hotPink.opacity(0.12)))
    }

    @MainActor
    private func pickImage() -> NSImage? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as icon"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return NSImage(contentsOf: url)  // only reads the picture, never changes it
    }
}

struct EditFolderSheet: View {
    @LocalState private var category: FolderCategory
    @LocalState private var extText: String
    @LocalState private var followsName: Bool
    @LocalState private var confirmRemove = false
    let isNew: Bool
    var onSave: (FolderCategory) -> Void
    var onRemove: ((FolderCategory) -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(category: FolderCategory, isNew: Bool,
         onSave: @escaping (FolderCategory) -> Void, onRemove: ((FolderCategory) -> Void)?) {
        _category = State(initialValue: category)
        _extText = State(initialValue: category.extensions.joined(separator: ", "))
        _followsName = State(initialValue: isNew)
        self.isNew = isNew
        self.onSave = onSave
        self.onRemove = onRemove
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "New folder ✨" : "Edit \(category.emoji) \(category.name)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.deepPink)

            Form {
                TextField("Name", text: $category.name, prompt: Text("e.g. School"))
                TextField("Emoji", text: $category.emoji)
                Picker("Color", selection: $category.color) {
                    ForEach(Pastel.allCases) { Text($0.label).tag($0) }
                }
                TextField("File types", text: $extText, prompt: Text("pdf, docx, png"), axis: .vertical)
                    .lineLimit(2...4)
                LabeledContent("Goes in") {
                    HStack {
                        Text(prettyPath(category.destination)).lineLimit(1).truncationMode(.middle)
                        Button("Choose…") {
                            if let url = pickFolder(start: Paths.sorted, prompt: "Put files here") {
                                category.destinationPath = url.path
                                followsName = false
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: category.name) {
                if followsName { category.destinationPath = Paths.sortedFolder(named: category.name).path }
            }

            if !isNew {
                Text("Changing the name here only changes the label. Your real folder is never renamed.")
                    .font(rounded(.caption)).foregroundStyle(.secondary)
            }

            HStack {
                if let onRemove {
                    Button("Remove from list") { confirmRemove = true }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                        .confirmationDialog("Remove \(category.name) from the list?", isPresented: $confirmRemove) {
                            Button("Remove", role: .destructive) { onRemove(category); dismiss() }
                        } message: {
                            Text("The folder and everything in it stay exactly where they are. The app just stops sorting into it.")
                        }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(CuteButtonStyle(prominent: false))
                    .keyboardShortcut(.cancelAction)
                Button("Save 💖") {
                    category.name = category.name.trimmingCharacters(in: .whitespaces)
                    category.extensions = FolderCategory.parseExtensions(extText)
                    if category.emoji.trimmingCharacters(in: .whitespaces).isEmpty { category.emoji = "📁" }
                    onSave(category)
                    dismiss()
                }
                .buttonStyle(CuteButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(category.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Theme.background)
    }
}
