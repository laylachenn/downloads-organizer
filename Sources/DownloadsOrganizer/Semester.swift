import Foundation

enum Season: String, CaseIterable, Identifiable, Codable {
    case spring, summer, fall, winter

    var id: String { rawValue }
    var order: Int {
        switch self {
        case .winter: 0
        case .spring: 1
        case .summer: 2
        case .fall: 3
        }
    }
    var emoji: String {
        switch self {
        case .spring: "🌷"
        case .summer: "☀️"
        case .fall: "🍂"
        case .winter: "❄️"
        }
    }
}

/// A folder whose name looks like a semester, e.g. "spring 2025", "Fall 2026", "2024 Fall", "fall '24".
struct Semester: Identifiable, Hashable {
    let url: URL
    let season: Season
    let year: Int

    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
    var sortKey: Int { year * 10 + season.order }
}

enum Semesters {
    static func parse(_ folderName: String) -> (season: Season, year: Int)? {
        let text = folderName.lowercased().trimmingCharacters(in: .whitespaces)
        let pattern = #"^(?:(spring|summer|fall|autumn|winter)[\s_\-]*'?(\d{4}|\d{2})|(\d{4})[\s_\-]*(spring|summer|fall|autumn|winter))$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }

        func group(_ i: Int) -> String? {
            guard let range = Range(match.range(at: i), in: text) else { return nil }
            return String(text[range])
        }
        guard var seasonText = group(1) ?? group(4),
              let yearText = group(2) ?? group(3),
              var year = Int(yearText) else { return nil }
        if seasonText == "autumn" { seasonText = "fall" }
        if year < 100 { year += 2000 }
        guard let season = Season(rawValue: seasonText) else { return nil }
        return (season, year)
    }

    /// Jan–May = spring, Jun–Jul = summer, Aug–Dec = fall.
    static func current(on date: Date = Date()) -> (season: Season, year: Int) {
        let parts = Calendar.current.dateComponents([.month, .year], from: date)
        let year = parts.year ?? 2026
        switch parts.month ?? 1 {
        case 1...5: return (.spring, year)
        case 6...7: return (.summer, year)
        default: return (.fall, year)
        }
    }

    static func sortKey(_ season: Season, _ year: Int) -> Int { year * 10 + season.order }

    /// Looks one level deep in each root for semester-named folders. Read-only.
    static func find(in roots: [URL]) -> [Semester] {
        var seen = Set<String>()
        var found: [Semester] = []
        for root in roots {
            let items = (try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for url in items {
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      let parsed = parse(url.lastPathComponent),
                      seen.insert(url.standardizedFileURL.path).inserted else { continue }
                found.append(Semester(url: url, season: parsed.season, year: parsed.year))
            }
        }
        return found.sorted { $0.sortKey > $1.sortKey }
    }

    /// Matches the style of existing folders: if they're all lowercase ("spring 2025"), new ones are too.
    static func folderName(_ season: Season, _ year: Int, existing: [Semester]) -> String {
        let lowercase = !existing.isEmpty && existing.allSatisfy { $0.name.first?.isLowercase == true }
        return "\(lowercase ? season.rawValue : season.rawValue.capitalized) \(year)"
    }
}
