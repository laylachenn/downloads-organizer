import SwiftUI
import AppKit

/// The new SDK turns `@State` into a macro whose plugin only ships with full Xcode.
/// This alias points at the plain `State` property wrapper so it builds with Command Line Tools.
typealias LocalState<Value> = SwiftUI.State<Value>

enum Pastel: String, Codable, CaseIterable, Identifiable {
    case pink, lavender, mint, peach, sky, butter

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var nsColor: NSColor {
        switch self {
        case .pink:     NSColor(red: 1.00, green: 0.71, blue: 0.82, alpha: 1)
        case .lavender: NSColor(red: 0.80, green: 0.73, blue: 1.00, alpha: 1)
        case .mint:     NSColor(red: 0.66, green: 0.92, blue: 0.82, alpha: 1)
        case .peach:    NSColor(red: 1.00, green: 0.80, blue: 0.68, alpha: 1)
        case .sky:      NSColor(red: 0.68, green: 0.85, blue: 1.00, alpha: 1)
        case .butter:   NSColor(red: 1.00, green: 0.93, blue: 0.62, alpha: 1)
        }
    }
    var color: Color { Color(nsColor: nsColor) }
}

enum Theme {
    static let hotPink = Color(red: 0.93, green: 0.36, blue: 0.62)
    static let deepPink = Color(red: 0.72, green: 0.22, blue: 0.48)
    static let text = Color(red: 0.36, green: 0.18, blue: 0.30)
    static let background = LinearGradient(
        colors: [Color(red: 1.0, green: 0.93, blue: 0.96), Color(red: 0.95, green: 0.92, blue: 1.0)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

func rounded(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
    .system(style, design: .rounded).weight(weight)
}

// MARK: - Styles

struct CuteCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.85)))
            .shadow(color: Theme.hotPink.opacity(0.12), radius: 10, y: 4)
    }
}

extension View {
    func cuteCard() -> some View { modifier(CuteCard()) }
}

struct CuteButtonStyle: ButtonStyle {
    var color: Color = Theme.hotPink
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        CuteButtonBody(configuration: configuration, color: color, prominent: prominent)
    }
}

private struct CuteButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(rounded(.body, .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(prominent ? Color.white : color)
            .background(Capsule().fill(prominent ? color : color.opacity(0.12)))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

// MARK: - Shared little views

struct PageHeader: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.deepPink)
                Text(subtitle)
                    .font(rounded(.callout))
                    .foregroundStyle(Theme.text.opacity(0.7))
            }
            Spacer()
        }
    }
}

struct Banner: View {
    let emoji: String
    let text: String
    var detail: String? = nil
    var tint: Pastel = .mint

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(rounded(.body, .semibold)).foregroundStyle(Theme.text)
                if let detail {
                    Text(detail).font(rounded(.caption)).foregroundStyle(Theme.text.opacity(0.7))
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.color.opacity(0.5)))
    }
}

struct EmptyHint: View {
    let emoji: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 56))
            Text(text)
                .font(rounded(.title3, .medium))
                .foregroundStyle(Theme.text.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileIcon: View {
    let url: URL
    var size: CGFloat = 22
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .frame(width: size, height: size)
    }
}

struct RevealButton: View {
    let url: URL
    var body: some View {
        Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: {
            Image(systemName: "magnifyingglass")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Theme.hotPink)
        .help("Show in Finder")
    }
}

// MARK: - Helpers

@MainActor
func pickFolder(start: URL?, prompt: String = "Choose") -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.directoryURL = start
    panel.prompt = prompt
    return panel.runModal() == .OK ? panel.url : nil
}

func prettyPath(_ url: URL) -> String {
    let home = Paths.home.path
    return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
}

func prettySize(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
