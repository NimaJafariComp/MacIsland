# MacIsland

MacIsland is a native macOS notch utility built with SwiftUI and AppKit. It
combines media controls, calendar and reminders, camera mirror, file shelf,
battery state, gestures, and native system HUDs in a notch-aware panel.

The native rebuild is in progress. See [PLAN.md](PLAN.md) for scope, design
rules, validation gates, and current status.

## Build the native app

Requirements:

- macOS 15.6 or later for development
- Xcode 26 or later

```bash
xcodebuild \
  -project MacIsland.xcodeproj \
  -scheme MacIsland \
  -configuration Debug \
  -derivedDataPath /private/tmp/macisland-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The product is written to:

```text
/private/tmp/macisland-derived/Build/Products/Debug/MacIsland.app
```

Open `MacIsland.xcodeproj` in Xcode to run with signing and permissions.

Run the full local delivery gate with:

```bash
Scripts/validate-xcode.sh
```

Release signing, notarization, GPL source-offer, and packaging requirements are
documented in [RELEASE.md](RELEASE.md). Credentials and signing keys are never
stored in this repository.

## Development workflow

MacIsland has one canonical build path: the Xcode project and the validation
commands above. The embedded XPC helper is built as part of the same project.

## Open-source foundation

MacIsland is derived from
[Boring Notch](https://github.com/TheBoredTeam/boring.notch) revision
`8dd02e7555cbe48899524c61d24e50703e68ff68`.

MacIsland is licensed under GPL-3.0. See [LICENSE](LICENSE). Third-party notices
are preserved in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
