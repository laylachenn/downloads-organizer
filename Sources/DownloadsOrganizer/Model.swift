import Foundation
import SwiftUI

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
    static let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
    static let documents = home.appendingPathComponent("Documents", isDirectory: true)

    /// Where the type folders (Documents, Pictures…) live, off the Desktop so it stays clear.
    static let sorted = documents.appendingPathComponent("Sorted", isDirectory: true)

    /// A sorting folder for a display name (slashes/colons aren't allowed in folder names).
    static func sortedFolder(named name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return sorted.appendingPathComponent(safe.isEmpty ? "New Folder" : safe, isDirectory: true)
    }

    static func same(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.path == b.standardizedFileURL.path
    }
}

/// A sorting rule: files with these extensions go into `destinationPath`.
struct FolderCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    var color: Pastel
    var extensions: [String]
    var destinationPath: String

    var destination: URL { URL(fileURLWithPath: destinationPath, isDirectory: true) }

    func matches(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return !ext.isEmpty && extensions.contains(ext)
    }

    static func parseExtensions(_ text: String) -> [String] {
        var seen = Set<String>()
        return text
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

@MainActor
final class Store: ObservableObject {
    // Type folders
    @Published var categories: [FolderCategory] { didSet { saveCategories() } }
    @Published var sourcePath: String { didSet { defaults.set(sourcePath, forKey: Keys.source) } }

    // School
    @Published var schoolPath: String { didSet { defaults.set(schoolPath, forKey: Keys.school); refreshSemesters() } }
    @Published var archivePath: String { didSet { defaults.set(archivePath, forKey: Keys.archive); refreshSemesters() } }
    @Published var currentSemesterPath: String? { didSet { defaults.set(currentSemesterPath, forKey: Keys.current) } }
    @Published var schoolExtensions: [String] { didSet { defaults.set(schoolExtensions, forKey: Keys.schoolExts) } }
    @Published var autoSort: Bool {
        didSet {
            defaults.set(autoSort, forKey: Keys.autoSort)
            // Only files downloaded after switching on get auto-sorted, so nothing old moves by surprise.
            autoSortSince = autoSort ? Date() : nil
            defaults.set(autoSortSince, forKey: Keys.autoSortSince)
            updateTimer()
        }
    }
    @Published private(set) var semesters: [Semester] = []

    // Navigation (Home browser)
    @Published var page: Page = .home
    @Published var browseStack: [URL] = []

    /// Jump to a folder in the Home browser.
    func browse(_ url: URL) {
        page = .home
        browseStack = [url]
    }
    @Published private(set) var recentAutoSorted: [String] = []

    private var autoSortSince: Date?
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let categories = "categories.v1"
        static let source = "sourcePath"
        static let school = "schoolPath"
        static let archive = "archivePath"
        static let current = "currentSemesterPath"
        static let schoolExts = "schoolExtensions"
        static let autoSort = "autoSort"
        static let autoSortSince = "autoSortSince"
    }

    static let semesterRuleID = UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!
    static let defaultSchoolExtensions = FolderCategory.parseExtensions("""
        pdf doc docx txt rtf pages md csv xls xlsx numbers ppt pptx key odt epub
        png jpg jpeg heic ipynb py java c cpp h js html css r m
        """)

    init() {
        var loaded = Store.starterFolders
        if let data = defaults.data(forKey: Keys.categories),
           let saved = try? JSONDecoder().decode([FolderCategory].self, from: data) {
            loaded = saved
        }
        // One-time: the type folders moved from ~/Desktop to ~/Documents/Sorted on 2026-11-07.
        if !defaults.bool(forKey: "migratedToSorted.v1") {
            loaded = loaded.map { c in
                var c = c
                if Paths.same(c.destination.deletingLastPathComponent(), Paths.desktop) {
                    c.destinationPath = Paths.sortedFolder(named: c.destination.lastPathComponent).path
                }
                return c
            }
            if let data = try? JSONEncoder().encode(loaded) { defaults.set(data, forKey: Keys.categories) }
            defaults.set(true, forKey: "migratedToSorted.v1")
        }
        categories = loaded
        sourcePath = defaults.string(forKey: Keys.source) ?? Paths.downloads.path

        // New semesters go next to the newest one you already have, else in Documents.
        let school = defaults.string(forKey: Keys.school)
            ?? Semesters.find(in: [Paths.home, Paths.desktop, Paths.documents]).first?.url
                .deletingLastPathComponent().path
            ?? Paths.documents.path
        schoolPath = school
        archivePath = defaults.string(forKey: Keys.archive)
            ?? URL(fileURLWithPath: school).appendingPathComponent("Archive", isDirectory: true).path
        currentSemesterPath = defaults.string(forKey: Keys.current)
        schoolExtensions = defaults.stringArray(forKey: Keys.schoolExts) ?? Store.defaultSchoolExtensions
        autoSort = defaults.bool(forKey: Keys.autoSort)
        autoSortSince = defaults.object(forKey: Keys.autoSortSince) as? Date

        refreshSemesters()
        updateTimer()
    }

    var source: URL { URL(fileURLWithPath: sourcePath, isDirectory: true) }
    var school: URL { URL(fileURLWithPath: schoolPath, isDirectory: true) }
    var archive: URL { URL(fileURLWithPath: archivePath, isDirectory: true) }

    // MARK: Type folders

    func upsert(_ category: FolderCategory) {
        if let i = categories.firstIndex(where: { $0.id == category.id }) {
            categories[i] = category
        } else {
            categories.append(category)
        }
    }

    /// Removes the rule only. The real folder on disk is never touched.
    func remove(_ category: FolderCategory) {
        categories.removeAll { $0.id == category.id }
    }

    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            defaults.set(data, forKey: Keys.categories)
        }
    }

    /// Current semester first (it wins for school file types), then the type folders.
    var sortingRules: [FolderCategory] {
        (semesterRule.map { [$0] } ?? []) + categories
    }

    var semesterRule: FolderCategory? {
        guard let url = currentSemesterURL else { return nil }
        return FolderCategory(id: Store.semesterRuleID, name: url.lastPathComponent, emoji: "🎓",
                              color: .lavender, extensions: schoolExtensions, destinationPath: url.path)
    }

    // MARK: Semesters

    var currentSemesterURL: URL? {
        guard let path = currentSemesterPath, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var activeSemesters: [Semester] { semesters.filter { !isArchived($0) } }
    var archivedSemesters: [Semester] { semesters.filter { isArchived($0) } }

    func isArchived(_ s: Semester) -> Bool { Paths.same(s.url.deletingLastPathComponent(), archive) }
    func isCurrent(_ s: Semester) -> Bool { currentSemesterURL.map { Paths.same($0, s.url) } ?? false }
    func isFinished(_ s: Semester) -> Bool {
        let now = Semesters.current()
        return s.sortKey < Semesters.sortKey(now.season, now.year)
    }

    func activeSemester(_ season: Season, _ year: Int) -> Semester? {
        activeSemesters.first { $0.season == season && $0.year == year }
    }

    func newSemesterName(_ season: Season, _ year: Int) -> String {
        Semesters.folderName(season, year, existing: semesters)
    }

    func refreshSemesters() {
        var roots = [Paths.home, Paths.desktop, Paths.documents, Paths.downloads]
        for extra in [school, archive] where !roots.contains(where: { Paths.same($0, extra) }) {
            roots.append(extra)
        }
        semesters = Semesters.find(in: roots)
        // If nothing's picked yet, use this semester's folder when it exists.
        if currentSemesterURL == nil {
            let now = Semesters.current()
            currentSemesterPath = activeSemester(now.season, now.year)?.url.path
        }
    }

    /// Makes (or reuses) a semester folder in the school folder and makes it current.
    func createSemester(_ season: Season, _ year: Int) throws {
        if let existing = activeSemester(season, year) {
            currentSemesterPath = existing.url.path
            return
        }
        let url = school.appendingPathComponent(newSemesterName(season, year), isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            IconMaker.setIcon(IconMaker.folderIcon(emoji: season.emoji, color: Pastel.lavender.nsColor), forFolder: url)
        }
        refreshSemesters()
        currentSemesterPath = url.path
    }

    /// Moves a whole semester folder into Archive (same name). Returns a problem message, or nil if it worked.
    func archiveSemester(_ s: Semester) -> String? {
        let fm = FileManager.default
        if !fm.fileExists(atPath: archive.path) {
            do {
                try fm.createDirectory(at: archive, withIntermediateDirectories: true)
                IconMaker.setIcon(IconMaker.folderIcon(emoji: "📦", color: Pastel.sky.nsColor), forFolder: archive)
            } catch {
                return "Couldn't make the Archive folder: \(error.localizedDescription)"
            }
        }
        let wasCurrent = isCurrent(s)
        let result = FileOps.moveFolder(s.url, into: archive)
        if result == nil && wasCurrent { currentSemesterPath = nil }
        refreshSemesters()
        return result
    }

    // MARK: Auto-sort

    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard autoSort else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.autoSortTick() }
        }
    }

    private func autoSortTick() {
        guard autoSort, let rule = semesterRule, let since = autoSortSince else { return }
        let moves = FileOps.plan(source: source, categories: [rule]).moves
            .filter { !$0.conflict && FileOps.isFreshAndFinished($0.source, since: since) }
        guard !moves.isEmpty else { return }
        let report = FileOps.execute(moves)
        recentAutoSorted = Array((report.moved + recentAutoSorted).prefix(20))
    }

    static var starterFolders: [FolderCategory] {
        func make(_ name: String, _ emoji: String, _ color: Pastel, _ exts: String) -> FolderCategory {
            FolderCategory(name: name, emoji: emoji, color: color,
                           extensions: FolderCategory.parseExtensions(exts),
                           destinationPath: Paths.sortedFolder(named: name).path)
        }
        // No Installers folder: those are better off in Clean Out.
        return [
            make("Documents", "📄", .pink, "pdf doc docx txt rtf pages md csv xls xlsx numbers ppt pptx key odt epub"),
            make("Pictures", "🌸", .lavender, "jpg jpeg png gif heic heif webp svg tiff tif bmp raw psd"),
            make("Videos", "🎬", .peach, "mov mp4 m4v avi mkv webm wmv"),
            make("Music", "🎵", .sky, "mp3 m4a wav aac flac aiff ogg"),
            make("Zips", "📦", .mint, "zip rar 7z tar gz tgz bz2 xz"),
        ]
    }
}
