import AppKit
import SwiftUI

struct ApplicationTile: View {
    let application: InstalledApplication
    let isPinned: Bool
    let onLaunch: () -> Void
    let onTogglePinned: () -> Void
    @State private var isHovered = false

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
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
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
                AppIcon(path: application.path, size: 42)

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
            .frame(height: 62)
            .background(rowBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct RecentApplicationRow: View {
    let application: InstalledApplication
    let onLaunch: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onLaunch) {
            HStack(spacing: 10) {
                AppIcon(path: application.path, size: 42)

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
            .frame(height: 62)
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
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
