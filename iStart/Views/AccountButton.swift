import AppKit
import Collaboration
import SwiftUI

struct AccountButton: View {
    var body: some View {
        Button {
            SystemSettingsOpener.openDefaultPage()
        } label: {
            HStack(spacing: 10) {
                AccountAvatar(size: 28)

                Text(displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(Text("Open System Settings"))
    }

    private var displayName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
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
}
