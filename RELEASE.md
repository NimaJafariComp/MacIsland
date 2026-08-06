# MacIsland release and source-offer checklist

## Local validation

Run `Scripts/validate-xcode.sh`. It builds Debug and Release, runs XCTest, and
checks the product identity, entitlements, and prohibited reference branding.

## Developer ID release

The project keeps hardened runtime enabled for both app configurations. Before
shipping, set the team in Xcode and select a valid **Developer ID Application**
certificate for the app and embedded XPC helper. Archive from Xcode, then verify
the archive contains `MacIsland.app`, the XPC helper, embedded frameworks, and
the GPL notices with `codesign --verify --deep --strict --verbose=2`.

### Login item and permission continuity

The in-app **Launch MacIsland at login** setting uses macOS's `SMAppService`
main-app login item. It is registered by the installed app and survives normal
launches and signed in-place updates; no bundled LaunchAgent is required.

macOS privacy grants (Camera, Calendar/Reminders, Location, Notifications, and
Accessibility) are stored by the system for the app's signing identity. Ship
the DMG and every update with the same `com.macisland.app` bundle identifier
and the same Developer ID Application team/signing identity. Do not replace an
installed release with an ad-hoc build or change the bundle identifier: macOS
will correctly treat that as a different app and may request permissions again.

## Notarization

Store the notarization profile or App Store Connect API key only in the release
CI secret store or the developer keychain. Never commit credentials, app-specific
passwords, profiles, or private signing keys. Submit the signed ZIP/DMG with
`xcrun notarytool submit`, wait for acceptance, then staple the accepted ticket.

After stapling, run:

```bash
Scripts/verify-distribution.sh /path/to/MacIsland.app
```

This rejects local/ad-hoc signatures and requires strict nested-code validation,
Developer ID authority, Gatekeeper assessment, and a stapled ticket.

## GPL source offer

Every distributed archive must include `LICENSE`, `NOTICE`,
`THIRD_PARTY_LICENSES`, and `SOURCE_CODE.txt`. The app bundle must include its
`NOTICE.md` and `THIRD_PARTY_NOTICES.md` resources.

`SOURCE_CODE.txt` must point to the exact corresponding `v<version>` source
tag, including dependency-resolution metadata and build instructions. Preserve
the Boring Notch attribution in `NOTICE`; do not use it as product branding.

## Updates

The updater remains disabled until a MacIsland-controlled HTTPS appcast, release
hosting, and Sparkle EdDSA signing key are available. Generate and retain that
key outside the repository; adding an update feed before this is a release block.
