import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationTile: View {
    let application: InstalledApplication
    let isPinned: Bool
    let onLaunch: () -> Void
    let onTogglePinned: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 8) {
                AppIcon(path: application.path, size: 42)

                Text(verbatim: application.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(isPinned ? String(localized: "Unpin from Start") : String(localized: "Pin to Start"), action: onTogglePinned)
        }
    }
}

struct SearchResultRow: View {
    let application: InstalledApplication
    let isPinned: Bool
    let isSelected: Bool
    let onLaunch: () -> Void
    let onTogglePinned: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            HStack(spacing: 12) {
                AppIcon(path: application.path, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: application.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Text(verbatim: application.bundleIdentifier ?? application.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isPinned ? "pin.fill" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(rowBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(isPinned ? String(localized: "Unpin from Start") : String(localized: "Pin to Start"), action: onTogglePinned)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct RecentItemRow: View {
    let item: RecentItem
    let onLaunch: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            HStack(spacing: 10) {
                FileIcon(url: item.url, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(item.kind.localizedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension RecentItemKind {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .application:
            "Application"
        case .document:
            "Document"
        case .folder:
            "Folder"
        case .server:
            "Server"
        case .other:
            "Recently opened"
        }
    }
}

struct AppIcon: View {
    let path: String
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private var icon: NSImage {
        AppIconCache.shared.icon(forFile: path, size: size)
    }
}

struct FileIcon: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private var icon: NSImage {
        if url.isFileURL {
            return AppIconCache.shared.icon(forFile: url.path, size: size)
        }

        let icon = NSWorkspace.shared.icon(for: .url)
        icon.size = NSSize(width: size, height: size)
        return icon
    }
}
