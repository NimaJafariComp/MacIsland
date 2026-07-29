# MacIsland independent code audit — task 8.1

Date: 2026-07-29  
Scope: architecture, dead paths, concurrency/lifecycle, privacy, accessibility,
dependencies, and release configuration.  
Verdict: **not ready for sign-off**. Two confirmed P1 security defects were
fixed in this run; critical release, high concurrency, high maintainability,
and prior-ledger blockers remain.

## Method and evidence

- Worker set: `ln-621` through `ln-629`, each read-only and independently
  reviewed. Hex Graph/Line MCP was unavailable, so workers used `rg` and
  contextual source inspection.
- Research: Apple [Foundation URL documentation](https://developer.apple.com/documentation/foundation/url),
  [AVCaptureSession documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession),
  and [SwiftUI accessibility guidance](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)
  (web, 2026-07-29); Swift actors/task-cancellation guidance (Context7,
  `/swiftlang/swift`, 2026-07-29). Ref MCP was unavailable.
- Validation after repair: `Scripts/validate-xcode.sh` passed Debug/Release,
  signing/branding checks, and 41 XCTest cases with 0 failures. Direct focused
  `xcodebuild test` initially hit host LaunchServices `IDELaunchErrorDomain 20`;
  the full project gate then executed the new test successfully.

## Confirmed P0/P1 findings

| Priority | Owner | Locations | Status and remediation |
| --- | --- | --- | --- |
| P1 security | ln-621 | `NSItemProvider+LoadHelpers.swift:39-58` | **Fixed.** Provider-owned file-promise URLs are no longer deleted. This removes attacker-controlled file/parent deletion. |
| P1 security | ln-621 | `TemporaryFileStorageService.swift:82-90` | **Fixed.** Suggested names are reduced to one safe leaf, sanitized, and checked to remain under the generated directory. XCTest covers traversal and separator input. Foundation `standardizedFileURL` semantics support the containment check. |
| P0 release | ln-622 | `project.pbxproj:1155,1366-1373`; `Scripts/verify-distribution.sh` | **Open external blocker.** No Developer ID identity/team; Release is ad-hoc and distribution gate exits 65. Install certificate/private key, archive, notarize/staple, then verify exact artifact. |
| P1 delivery | ln-622 | `.github/workflows` absent; `Scripts/validate-xcode.sh:23-41` | **Open.** No CI produces Developer-ID/notarized artifact; add credentialed release CI only after release identity is available. |
| P1 concurrency | ln-628 | `ImageProcessingService.swift:50,60,127,244`; `TemporaryFileStorageService.swift:185-285` | **Open.** Image/PDF processing and `zip` plus `waitUntilExit()` can execute on MainActor. Move work to single cancellable background worker; publish results on MainActor. Apple documents camera blocking work must avoid the main queue; same responsiveness principle applies. |
| P1 maintainability | ln-624 | `SettingsView.swift:97`; `MusicManager.swift:194`; `ShelfItemViewModel.swift:415` | **Open.** Three large, multi-responsibility hotspots require staged extraction. Do not combine with this security repair; preserve resolver/coordinator ownership. |

## Other prioritized findings

| Severity | Worker | Locations | Action |
| --- | --- | --- | --- |
| Medium | ln-621 | `MacIsland.entitlements:21-22` | Remove unused network-server entitlement after release regression check. |
| Medium | ln-621 | `MacIslandXPCHelper/main.swift:13-27`; helper entitlement | Confirm embedded-XPC caller provenance; otherwise authorize caller/audit token and minimize helper. |
| Medium | ln-623 | two `MacIslandXPCHelperProtocol.swift` copies | Share one protocol source across app/helper targets. |
| Medium | ln-623 | `ImageService.swift:11-15`; `CalendarServiceProviding.swift:13-19` | Remove unused protocols or introduce actual injected consumers. |
| Medium | ln-624 | `BoringViewCoordinator.swift`, `ContentView.swift`, `MacIslandApp.swift`, `ShelfItemViewModel.swift` | Split feature responsibilities in later, tested refactors; typed Shelf menu actions instead of title dispatch. |
| Medium | ln-625 | `project.pbxproj` SPM refs | Remove unused `swift-collections`; remove two duplicate MacroVisionKit product links. |
| Low | ln-625 | `Package.resolved` / pbxproj | Remove unused Pow package reference. |
| Medium | ln-626 | `TestView.swift`, `BottomRoundedRectangle.swift`, `WhatsNewView.swift` | Delete proven-unreferenced views and PBX refs. |
| Low | ln-626 | commented code in Content, Calendar, Settings | Remove stale commented blocks. |
| Medium | ln-627 | `Logger.swift`, `XPCHelperClient.swift`, weather/camera errors | Use privacy-safe `os.Logger` categories and rate-limited failure signals. |
| Medium | ln-628 | `XPCHelperClient.swift`; `ShelfStateViewModel.swift`; temp writes | MainActor-isolate monitor state; serialize Shelf persistence and move I/O off main actor. |
| Medium | ln-629 | `MacIslandApp.swift:71,58,194,297,577` | Stop media interceptor on termination; key screen-change observer tokens per window and remove them during teardown. |

## Clean or excluded areas

- No committed secrets, SQL/XSS sinks, sensitive environment defaults, deadlock,
  TOCTOU, or confirmed cross-process write race.
- Camera session work is serialized on its session queue; timer/weather use
  cancellation/generation guards. Standard SwiftUI/AppKit controls include
  targeted accessibility labels for custom island surfaces.
- No server/container deployment exists, so HTTP probes, request correlation,
  and startup environment validation are inapplicable.

## Deduplication and next acceptance checks

- `ln-621` owns exploitable file handling; `ln-628` owns responsiveness of the
  same temporary-file service. Their remediation must retain the containment
  invariant added here.
- `ln-622` owns release gate; certificate/notarization is external rather than
  a source-code defect. `ln-625` owns dependency removal.
- Before sign-off: close task-7 proof gaps, credentialed distribution gate,
  the P1 concurrency and hotspot plans above, then rerun this audit and the
  release/screenshot matrices.

## Cleanup

Workers returned transport summaries only; no temporary worker markdown reports
were created. Consolidated report is sole audit markdown artifact.
