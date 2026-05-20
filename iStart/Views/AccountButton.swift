import AppKit
import Collaboration
import SwiftUI

struct AccountButton: View {
    let onPowerAction: (PowerAction) -> Void

    var body: some View {
        Menu {
            ForEach(PowerAction.accountActions) { action in
                Button {
                    onPowerAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }

            Divider()

            Button {
                NotificationCenter.default.post(name: .startMenuShouldHide, object: nil)
                SystemSettingsOpener.openDefaultPage()
            } label: {
                Label(String(localized: "Open System Settings"), systemImage: "gearshape")
            }
        } label: {
            accountLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .help(Text("Account"))
    }

    private var displayName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }

    private var accountLabel: some View {
        HStack(spacing: 10) {
            AccountAvatar(size: 28)

            Text(displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Image(systemName: "chevron.up")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct AccountAvatar: View {
    let size: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task {
            image = await AccountAvatarProvider.currentUserImage(size: size)
        }
    }
}

enum AccountAvatarProvider {
    static func currentUserImage(size: CGFloat) async -> NSImage? {
        await Task.detached(priority: .utility) {
            let authority = CBIdentityAuthority.default()
            guard let identity = CBUserIdentity(posixUID: getuid(), authority: authority),
                  let image = identity.image else {
                return nil
            }

            image.size = NSSize(width: size, height: size)
            return image
        }.value
    }
}

enum SystemSettingsOpener {
    static func openDefaultPage() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    static func openSpotlightShortcutsPage() {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts",
            "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"
        ]

        for candidateURL in candidateURLs {
            guard let url = URL(string: candidateURL),
                  NSWorkspace.shared.open(url)
            else {
                continue
            }

            return
        }

        openDefaultPage()
    }
}
