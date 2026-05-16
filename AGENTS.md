# Repository Guidelines

## Project Structure & Module Organization

This repository contains a macOS SwiftUI app named `iStart`.

- `iStart.xcodeproj/`: Xcode project and build configuration.
- `iStart/App/`: app entry point, `NSApplicationDelegate`, window and Dock/hotkey integration.
- `iStart/Views/`: SwiftUI views for the Start-menu style launcher, settings, app rows, and account footer.
- `iStart/Models/`: small value models such as `InstalledApplication` and `HotKey`.
- `iStart/Services/`: app scanning, persistence, and launcher state.
- `iStart/Support/`: lightweight shared glue such as notification names.
- `iStart/Assets.xcassets/`: app icons, accent colors, and other asset catalog content.
- `iStart/en.lproj/` and `iStart/zh-Hans.lproj/`: localized `Localizable.strings` and `InfoPlist.strings`.
- `iStartTests/` and `iStartUITests/`: unit and UI tests.

## Build, Test, and Development Commands

Use a full Xcode installation for project builds. If `xcodebuild` reports Command Line Tools only, switch with:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Common commands:

```sh
xcodebuild -list -project iStart.xcodeproj
xcodebuild -project iStart.xcodeproj -scheme iStart -configuration Debug build
xcodebuild test -project iStart.xcodeproj -scheme iStart
swiftc -typecheck iStart/**/*.swift
```

`swiftc -typecheck` is a fast source-level sanity check, but it is not a replacement for an Xcode build.

## Coding Style & Naming Conventions

Write Swift with 4-space indentation and keep files focused on one primary type. Use `PascalCase` for types, `camelCase` for properties and functions, and descriptive names such as `ApplicationScanner` or `StartMenuWindowController`.

Prefer SwiftUI for UI and keep AppKit bridges narrow and explicit. Use semantic colors, materials, and localized strings. Display app names with `Text(verbatim:)` so system-localized app names are not re-localized by iStart.

## Testing Guidelines

Unit tests use Swift Testing in `iStartTests`; UI tests use XCTest in `iStartUITests`. Add tests for service logic, persistence, and edge cases such as app-name resolution. Name tests after behavior, for example `scannerDoesNotExposeAppExtensionAsDisplayName`.

Run the full Xcode test suite before submitting changes when Xcode is available.

## Commit & Pull Request Guidelines

The current history only contains an initial commit, so follow a simple imperative style: `Add localized app name resolution`, `Fix settings button behavior`.

Pull requests should include a short summary, user-visible behavior changes, test results, and screenshots or screen recordings for UI changes. Note any environment limitations, especially if `xcodebuild` could not run locally.

## Agent-Specific Instructions

Avoid reverting unrelated user changes. Keep localization files updated when adding user-facing text. For launcher behavior, verify Dock click, hotkey, search focus, app launch, and multi-display window placement when possible.
