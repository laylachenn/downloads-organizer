import Foundation
import AppKit

// `DownloadsOrganizer --make-iconset <dir>` writes the app icon PNGs (used by build.sh).
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--make-iconset"), i + 1 < args.count {
    do {
        try IconMaker.writeIconset(to: URL(fileURLWithPath: args[i + 1], isDirectory: true))
        exit(0)
    } catch {
        FileHandle.standardError.write("Could not write iconset: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

// `DownloadsOrganizer --buddy-icon <folder> <buddy> <pastel>` sets a mochi buddy icon on a folder.
// `DownloadsOrganizer --buddy-preview <out.png>` renders all buddies side by side.
if let i = args.firstIndex(of: "--buddy-icon"), i + 3 < args.count,
   let buddy = Buddy(rawValue: args[i + 2]), let color = Pastel(rawValue: args[i + 3]) {
    let ok = IconMaker.setIcon(IconMaker.buddyIcon(buddy, color: color.nsColor),
                               forFolder: URL(fileURLWithPath: args[i + 1], isDirectory: true))
    print(ok ? "icon set" : "could not set icon")
    exit(ok ? 0 : 1)
}
if let i = args.firstIndex(of: "--buddy-preview"), i + 1 < args.count {
    let size: CGFloat = 256
    let sheet = NSImage(size: NSSize(width: size * CGFloat(Buddy.allCases.count), height: size), flipped: false) { _ in
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: size * CGFloat(Buddy.allCases.count), height: size).fill()
        for (n, b) in Buddy.allCases.enumerated() {
            IconMaker.buddyIcon(b, color: Pastel.allCases[n % Pastel.allCases.count].nsColor).draw(in: NSRect(x: CGFloat(n) * size, y: 0, width: size, height: size))
        }
        return true
    }
    let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[i + 1]))
    exit(0)
}

DownloadsOrganizerApp.main()
