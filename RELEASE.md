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

## Notarization

Store the notarization profile or App Store Connect API key only in the release
CI secret store or the developer keychain. Never commit credentials, app-specific
passwords, profiles, or private signing keys. Submit the signed ZIP/DMG with
`xcrun notarytool submit`, wait for acceptance, then staple the accepted ticket.

## GPL source offer

Every distributed archive must include `LICENSE` and `THIRD_PARTY_LICENSES`.
Publish the exact corresponding source revision, including dependency resolution
metadata and build instructions, alongside the binary or provide a clear written
offer directing recipients to it. Preserve Boring Notch attribution.

## Updates

The updater remains disabled until a MacIsland-controlled HTTPS appcast, release
hosting, and Sparkle EdDSA signing key are available. Generate and retain that
key outside the repository; adding an update feed before this is a release block.
