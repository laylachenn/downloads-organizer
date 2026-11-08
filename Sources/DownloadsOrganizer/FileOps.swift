import Foundation

// GOLDEN RULE: never rename and never permanently delete the user's files.
// - Moves keep the exact same filename; if that name is taken at the destination, the file is skipped.
// - "Deleting" means Move to Trash, and only after the user confirms in the UI.

struct PlannedMove: Identifiable, Hashable {
    let id = UUID()
    let source: URL
    let category: FolderCategory
    let destination: URL
    /// A file with the same name is already in the destination, so this one will be skipped.
    let conflict: Bool
}

struct MoveReport {
    var moved: [String] = []
    var skipped: [String] = []
    var failed: [(name: String, reason: String)] = []
}

struct OldItem: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let added: Date
    var id: URL { url }
}

enum FileOps {
    /// Still downloading, so leave these alone.
    static let inProgressExtensions: Set<String> = ["crdownload", "download", "part", "partial", "opdownload"]

    /// Top-level files and packages (like .app) in a folder. Hidden files, plain folders
    /// and in-progress downloads are never included.
    static func topLevelItems(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return items.filter { url in
            if inProgressExtensions.contains(url.pathExtension.lowercased()) { return false }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true && values?.isPackage != true { return false }
            return true
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    // MARK: Tidy up

    static func plan(source: URL, categories: [FolderCategory]) -> (moves: [PlannedMove], unmatched: [URL]) {
        let fm = FileManager.default
        var moves: [PlannedMove] = []
        var unmatched: [URL] = []
        for url in topLevelItems(in: source) {
            guard let category = categories.first(where: { $0.matches(url) }) else {
                unmatched.append(url)
                continue
            }
            // Destination is the folder we're scanning, so it's already in place.
            if category.destination.standardizedFileURL.path == source.standardizedFileURL.path { continue }
            let destination = category.destination.appendingPathComponent(url.lastPathComponent)
            moves.append(PlannedMove(source: url, category: category, destination: destination,
                                     conflict: fm.fileExists(atPath: destination.path)))
        }
        return (moves, unmatched)
    }

    /// Moves each file into its folder with the same name. Never overwrites, never renames.
    static func execute(_ moves: [PlannedMove]) -> MoveReport {
        let fm = FileManager.default
        var report = MoveReport()
        for move in moves {
            let name = move.source.lastPathComponent
            do {
                // Re-check right before moving, since things may have changed since the plan.
                guard fm.fileExists(atPath: move.source.path) else { continue }
                if fm.fileExists(atPath: move.destination.path) {
                    report.skipped.append(name)
                    continue
                }
                try fm.createDirectory(at: move.category.destination, withIntermediateDirectories: true)
                try fm.moveItem(at: move.source, to: move.destination)
                report.moved.append(name)
            } catch {
                report.failed.append((name, error.localizedDescription))
            }
        }
        return report
    }

    /// For auto-sort: downloaded after `since`, and not written to for a few seconds (so it's done downloading).
    static func isFreshAndFinished(_ url: URL, since: Date) -> Bool {
        var url = url
        url.removeAllCachedResourceValues()  // always read the latest dates from disk
        guard let v = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .contentModificationDateKey, .creationDateKey])
        else { return false }
        let added = v.addedToDirectoryDate ?? v.creationDate ?? .distantPast
        let modified = v.contentModificationDate ?? .distantPast
        return added >= since && Date().timeIntervalSince(modified) > 5
    }

    /// Moves a whole folder into another folder, keeping its name. Never merges, overwrites or renames:
    /// if something with that name is already there, nothing moves. Returns a problem message, or nil.
    static func moveFolder(_ folder: URL, into parent: URL) -> String? {
        let fm = FileManager.default
        let destination = parent.appendingPathComponent(folder.lastPathComponent, isDirectory: true)
        if fm.fileExists(atPath: destination.path) {
            return "“\(folder.lastPathComponent)” is already in \(parent.lastPathComponent), so it stayed where it is."
        }
        do {
            try fm.moveItem(at: folder, to: destination)
            return nil
        } catch {
            return "Couldn't move “\(folder.lastPathComponent)”: \(error.localizedDescription)"
        }
    }

    /// Moves files/folders into `destination`, keeping their names. Never overwrites: if the name is taken,
    /// that item stays put. Also refuses to move a folder into itself. Returns what moved (for Undo).
    static func moveItems(_ urls: [URL], into destination: URL) -> (moved: [(from: URL, to: URL)], skipped: [String], failed: [String]) {
        let fm = FileManager.default
        var moved: [(URL, URL)] = []
        var skipped: [String] = []
        var failed: [String] = []
        let destPath = destination.standardizedFileURL.path
        for url in urls {
            let name = url.lastPathComponent
            let path = url.standardizedFileURL.path
            if path == destPath || destPath.hasPrefix(path + "/") || Paths.same(url.deletingLastPathComponent(), destination) {
                skipped.append(name)
                continue
            }
            let target = destination.appendingPathComponent(name)
            if fm.fileExists(atPath: target.path) {
                skipped.append(name)
                continue
            }
            do {
                try fm.moveItem(at: url, to: target)
                moved.append((url, target))
            } catch {
                failed.append(name)
            }
        }
        return (moved, skipped, failed)
    }

    static func itemCount(in folder: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.filter { !$0.hasPrefix(".") }.count ?? 0
    }

    // MARK: Clean out

    static func oldItems(in folder: URL, olderThanDays days: Int) -> [OldItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let keys: Set<URLResourceKey> = [.addedToDirectoryDateKey, .contentModificationDateKey]
        return topLevelItems(in: folder).compactMap { url -> OldItem? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            let added = values.addedToDirectoryDate ?? values.contentModificationDate ?? Date()
            guard added < cutoff else { return nil }
            return OldItem(url: url, size: size(of: url), added: added)
        }
        .sorted { $0.added < $1.added }
    }

    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        func bytes(_ v: URLResourceValues?) -> Int64 { Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0) }
        let values = try? url.resourceValues(forKeys: keys)
        guard values?.isDirectory == true else { return bytes(values) }
        var total: Int64 = 0
        if let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) {
            for case let file as URL in walker {
                total += bytes(try? file.resourceValues(forKeys: keys))
            }
        }
        return total
    }

    /// Moves items to the Trash, where they can still be recovered. Never deletes permanently.
    static func moveToTrash(_ urls: [URL]) -> (trashed: Int, failed: [String]) {
        var trashed = 0
        var failed: [String] = []
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                trashed += 1
            } catch {
                failed.append(url.lastPathComponent)
            }
        }
        return (trashed, failed)
    }
}
