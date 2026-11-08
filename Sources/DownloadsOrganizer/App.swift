import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Keep running in the menu bar while auto-sort is on, so new downloads still get sorted.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: "autoSort")
    }
}

struct DownloadsOrganizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup("Downloads Organizer", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 880, minHeight: 600)
                .preferredColorScheme(.light)
                .tint(Theme.hotPink)
        }
        .defaultSize(width: 1000, height: 700)

        MenuBarExtra {
            MenuBarContent().environmentObject(store)
        } label: {
            Image(systemName: store.autoSort ? "heart.fill" : "heart")
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let current = store.currentSemesterURL {
            Text("🎓 \(current.lastPathComponent)")
        } else {
            Text("No current semester yet")
        }
        if let current = store.currentSemesterURL {
            Button("Open \(current.lastPathComponent) 💖") {
                store.browse(current)
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Show \(current.lastPathComponent) in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: current.path)
            }
            Divider()
        }
        Toggle("Auto-sort new downloads", isOn: $store.autoSort)
            .disabled(store.currentSemesterURL == nil)
        if !store.recentAutoSorted.isEmpty {
            Divider()
            Text("Recently sorted")
            ForEach(Array(store.recentAutoSorted.prefix(5).enumerated()), id: \.offset) { _, name in
                Text("  \(name)")
            }
        }
        Divider()
        Button("Open Downloads Organizer") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

enum Page: String, CaseIterable, Identifiable {
    case home, school, tidy, cleanup, folders
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "Home"
        case .school: "School"
        case .tidy: "Tidy Up"
        case .cleanup: "Clean Out"
        case .folders: "My Folders"
        }
    }
    var emoji: String {
        switch self {
        case .home: "🏠"
        case .school: "🎓"
        case .tidy: "✨"
        case .cleanup: "🧹"
        case .folders: "🎀"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Group {
                switch store.page {
                case .home: HomeView()
                case .school: SchoolView()
                case .tidy: TidyView()
                case .cleanup: CleanupView()
                case .folders: FoldersView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("🎀").font(.system(size: 30))
                Text("Downloads\nOrganizer")
                    .font(rounded(.headline, .bold))
                    .foregroundStyle(Theme.deepPink)
            }
            .padding(.bottom, 18)

            ForEach(Page.allCases) { p in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        if p == .home { store.browseStack = [] }
                        store.page = p
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(p.emoji)
                        Text(p.title).font(rounded(.body, .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .foregroundStyle(store.page == p ? Color.white : Theme.text)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(store.page == p ? Theme.hotPink : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if let current = store.currentSemesterURL {
                Text("Quick").font(rounded(.caption, .bold)).foregroundStyle(Theme.text.opacity(0.5))
                    .padding(.top, 14).padding(.leading, 4)
                Button { store.browse(current) } label: {
                    HStack(spacing: 8) {
                        FileIcon(url: current, size: 22)
                        Text(current.lastPathComponent).font(rounded(.body, .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .foregroundStyle(Theme.deepPink)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Pastel.lavender.color.opacity(0.45)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("1", modifiers: .command)
                .help("Open \(current.lastPathComponent) (⌘1)")
            }

            Spacer()

            if store.autoSort, let current = store.currentSemesterURL {
                Text("🩷 Auto-sorting into \(current.lastPathComponent)")
                    .font(rounded(.caption, .semibold))
                    .foregroundStyle(Theme.deepPink)
                    .padding(.bottom, 6)
            }

            Text("💕 Nothing is ever renamed or permanently deleted. Clean Out only uses the Trash, so you can always get things back.")
                .font(rounded(.caption))
                .foregroundStyle(Theme.text.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 210)
        .background(Color.white.opacity(0.5))
    }
}
