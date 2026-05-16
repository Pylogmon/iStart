import AppKit
import SwiftUI

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
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(isPinned ? String(localized: "Unpin from Start") : String(localized: "Pin to Start"), action: onTogglePinned)
        }
    }
}

struct RecentApplicationRow: View {
    let application: InstalledApplication
    let onLaunch: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            HStack(spacing: 10) {
                AppIcon(path: application.path, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: application.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text("Recently opened")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: size, height: size)
        return image
    }
}
