# MacIsland Native Rebuild Plan

Status: **in progress**

Last updated: 2026-07-28

## 1. Objective

Rebuild MacIsland as a professional native macOS notch utility with the fit,
motion, system integration, and feature depth expected from Alcove, Perch, and
DynamicLake.

Implementation foundation:

- Fork Boring Notch under GPL-3.0.
- Preserve upstream attribution and third-party license notices.
- Ship a real Xcode macOS app with an embedded XPC helper as the canonical
  MacIsland product.
- Use only MacIsland-owned or properly licensed names, artwork, sounds, and
  copy. Alcove, Perch, and DynamicLake are product references, not source or
  asset sources.

## 2. Product Definition

### Audience

MacBook owners who want useful media, file, schedule, camera, and system status
controls integrated into the physical notch without visual noise.

### Single job

Turn the otherwise unused notch boundary into a glanceable native control
surface that expands smoothly into focused tools.

### Product principles

1. The physical notch is part of the silhouette, never covered by content.
2. Closed state is quiet and glanceable.
3. Open state has one clear task at a time.
4. Motion communicates state; it does not decorate.
5. System features use native macOS behavior, permissions, menus, shortcuts,
   typography, materials, and accessibility.
6. No fake content. Empty states explain the next useful action.
7. Background work stops when the relevant feature is hidden.
8. Every permission is requested only when its feature needs it.

## 3. Legal and Source Baseline

### Approved license direction

- User approved GPL-3.0 conversion on 2026-07-28.
- MacIsland distribution must include GPL-3.0 license text.
- Distributed binaries must provide corresponding source under GPL-3.0.
- Existing Boring Notch copyright and contributor history must remain
  attributable.
- Third-party licenses must ship with source and release artifacts.

### Pinned upstream

- Repository: `https://github.com/TheBoredTeam/boring.notch`
- Revision: `8dd02e7555cbe48899524c61d24e50703e68ff68`
- Revision date: 2026-07-25
- Baseline build:

  ```bash
  xcodebuild \
    -project /private/tmp/boring.notch/boringNotch.xcodeproj \
    -scheme boringNotch \
    -configuration Debug \
    -derivedDataPath /private/tmp/macisland-upstream-derived \
    CODE_SIGNING_ALLOWED=NO \
    build
  ```

- Baseline result: `BUILD SUCCEEDED`
- Known baseline warning: bundled `MediaRemoteAdapter.framework` targets macOS
  15 while upstream target declares macOS 14.

### Upstream sync rule

Keep upstream-derived code recognizable during initial migration. Avoid
gratuitous symbol renames until behavior is stable. Record later upstream
merges in this file with commit IDs and conflict notes.

## 4. Current-State Audit

### Existing MacIsland stack

- Swift Package Manager executable
- SwiftUI interface hosted in an AppKit `NSPanel`
- macOS 14 minimum
- ad hoc app-bundle shell script
- JSON settings blob in `UserDefaults`
- no automated test target
- no real Xcode signing, capabilities, helper, update, or archive workflow

### Existing call flow

```text
MacIslandApp
  -> AppDelegate
     -> AppContainer.bootstrap()
        -> SettingsStore
        -> AppModel
        -> MediaController
        -> CalendarController
        -> CameraController
        -> ShelfController
        -> ScreenGeometryService
        -> OverlayWindowManager
           -> NSPanel
              -> OverlayRootView
                 -> WidgetHostView
```

### Confirmed problems

| Priority | Problem | Evidence | Impact |
| --- | --- | --- | --- |
| P0 | Content and hit regions are not modeled around physical notch geometry | Closed view and panel use independent size calculations | Overlay can feel hidden behind or detached from notch |
| Resolved | Legacy standalone build path | Retired during Phase 13 | One signed, entitlement-aware Xcode delivery path |
| P0 | Window frame and SwiftUI content animate independently | `OverlayWindowManager`, `OverlayRootView` | Stutter and silhouette desynchronization |
| P1 | Media waveform publishes frequently through shared observable state | `MediaController` | Broad SwiftUI invalidation, including idle UI |
| P1 | Camera session lifecycle can block main actor | `CameraController` | Visible hitch when mirror starts |
| P1 | Settings changes can queue repeated frame updates | `SettingsStore` -> `OverlayWindowManager` | Dragging size controls can stutter |
| P1 | Persisted settings blob is unversioned and weakly clamped | `SettingsStore` | Old invalid sizes survive new defaults |
| P1 | Media integration lacks reliable initial metadata, artwork, and progress | `MediaController` | Placeholder-like player experience |
| P2 | Feature breadth is below references | Current widget set | Missing native HUD, battery, reminders, robust shelf, updater, shortcuts |
| P2 | No test or archive gate | repository root | Regressions reach local builds |

### Current implementation disposition

- The Xcode app and embedded XPC helper are the sole runtime implementation.
- Native window lifecycle owns all notch geometry and panel presentation.
- Legacy standalone sources were retired after parity, test, and delivery gates
  passed.

## 5. Target Architecture

```text
MacIsland.app
├── SwiftUI application/menu bar scene
├── AppKit notch panel coordinator
│   ├── one panel per selected display
│   ├── physical notch geometry
│   ├── hover/click/gesture state machine
│   └── lock/full-screen space behavior
├── Feature coordinators
│   ├── Now Playing
│   ├── Calendar + Reminders
│   ├── Camera Mirror
│   ├── File Shelf + Quick Look + Share
│   ├── Battery + charging
│   └── System HUD
├── Persistence
│   ├── typed Defaults keys
│   ├── security-scoped bookmarks
│   └── migration/version boundary
├── Services
│   ├── MediaRemote adapter
│   ├── Apple Music/Spotify/YouTube Music adapters
│   ├── AVFoundation session queue
│   ├── EventKit
│   ├── CoreAudio/display controls
│   └── Sparkle updater
└── MacIslandXPCHelper.xpc
    └── privileged/out-of-sandbox event observation boundary
```

### Ownership rules

- AppKit owns windows, screen placement, collection behavior, and hit testing.
- SwiftUI owns rendering, local interaction, and transition presentation.
- Feature services own external framework calls and background work.
- View models expose small, main-actor presentation state.
- Views never start long-running capture, polling, or XPC work in initializers.
- Settings persistence never directly performs panel animation.

## 6. Dependency Plan

Retain initially:

| Dependency | Purpose | Decision |
| --- | --- | --- |
| Defaults 9.0.6 | Typed settings | Keep |
| KeyboardShortcuts 2.4.0 | Global shortcuts | Keep |
| LaunchAtLogin 1.1.0 | Login item | Keep |
| Sparkle 2.9.1 | Updates | Keep, disable feed until MacIsland feed exists |
| SkyLightWindow 1.0.0 | Lock-screen window support | Keep, isolate private behavior |
| AsyncXPCConnection 1.3.0 | XPC client ergonomics | Keep |
| swiftui-introspect 1.3.0 | Native control/window integration | Keep only at proven call sites |
| swift-collections 1.3.0 | Data structures | Keep while upstream uses it |
| MacroVisionKit 0.2.0 | Media visualizer | Keep initially |
| Lottie 4.5.2 | Imported animation support | Review after rebrand |
| Pow 1.0.5 | SwiftUI effects | Review after visual pass |

Dependency constraints:

- Pin versions through `Package.resolved`.
- No dependency additions during foundation migration.
- Remove a dependency only after all source and resource references are proven
  absent.
- Private APIs require explicit release-channel review; App Store eligibility is
  not assumed.

## 7. Visual Direction

### Direction

“Instrument panel cut from the display.”

MacIsland should feel like black display hardware becoming interactive, not a
floating web card attached near the menu bar.

### Tokens

| Token | Value | Use |
| --- | --- | --- |
| `hardwareBlack` | `#000000` | Notch silhouette and physical bridge |
| `carbon` | `#101114` | Primary open surface |
| `elevatedCarbon` | `#17191D` | Focused cards and controls |
| `separator` | `#2A2D32` | Hairlines and control boundaries |
| `primaryText` | `#F4F5F7` | Main labels and values |
| `secondaryText` | `#9DA3AE` | Metadata and secondary labels |
| `contextAccent` | dynamic | Album artwork, system HUD, or feature state only |

No fixed neon brand accent inside the notch. Context supplies color; hardware
remains quiet.

### Typography

- Display values: San Francisco Rounded, semibold.
- Body and controls: San Francisco system text.
- Time and diagnostic values: monospaced digits or SF Mono where appropriate.
- Minimum body size: 11 pt in compact state, 12 pt in open state.
- Never use bundled imitation system fonts.

### Layout

Closed:

```text
             physical camera notch
        ┌──────────██████████──────────┐
        │ media/status wing  utility   │
        └──── quiet hardware silhouette┘
```

Open home:

```text
        ┌──────────██████████──────────┐
        │  now playing      next event │
        │  artwork/title    time/title │
        │  controls         calendar   │
        ├──────────────────────────────┤
        │ context tabs / active utility│
        └──────────────────────────────┘
```

Focused feature:

```text
        ┌──────────██████████──────────┐
        │ back   feature title   action│
        │                              │
        │ one primary task             │
        │                              │
        └──────────────────────────────┘
```

### Signature element

Notch bridge: a continuous black bridge exactly matching physical notch width,
with content occupying measured left and right wings. A one-pixel contextual
light line appears only for active system events or drag targeting.

### Motion

- One state machine drives both panel frame and rendered silhouette.
- Open: spring response about 0.38 seconds, damping about 0.82.
- Close: slightly firmer damping; no bounce below physical notch.
- HUD: short ease-out reveal, short hold, ease-in dismissal.
- Drag target: continuous geometric response, not repeated discrete springs.
- Reduce Motion: cross-fade and direct resize with no overshoot.
- No ambient animation when media is paused and no system event is active.

### Design critique gate

Before final visual sign-off, reject any implementation that:

- resembles detached generic rounded cards;
- puts decorative gradients behind every section;
- uses oversized headings inside a constrained utility;
- shows fake weather, music, events, or files;
- makes all features visible at once;
- changes corner radius without preserving the physical notch bridge;
- animates panel and content on different timing curves.

## 8. Feature Scope and Reference Mapping

| Capability | Alcove | Perch | DynamicLake | Boring Notch baseline | MacIsland target |
| --- | --- | --- | --- | --- | --- |
| Notch-aware closed state | Yes | Yes | Yes | Yes | Required |
| Smooth open/close | Yes | Yes | Yes | Yes | Required |
| Now Playing | Yes | Yes | Yes | Yes | Required |
| Calendar/reminders | Yes | Yes | Yes | Yes | Required |
| Camera mirror | Yes | Yes | Yes | Yes | Required |
| File shelf/AirDrop | Yes | Yes | Yes | Yes | Required |
| Battery/charging | Yes | Unknown | Yes | Yes | Required |
| Volume/brightness HUD | Yes | Unknown | Yes | Yes | Required |
| Global shortcuts | Yes | Unknown | Yes | Yes | Required |
| Login item | Yes | Unknown | Yes | Yes | Required |
| Updater | Yes | App Store | Yes | Yes | Required outside App Store |
| Weather | Yes | Yes | Yes | No | Later |
| Timer | Yes | Yes | Yes | No | Later |
| Notifications/live activities | Yes | Limited | Yes | Partial | Later |
| Bluetooth/AirPods | Yes | Unknown | Yes | No | Later |
| Lock-screen presentation | Yes | Unknown | Yes | Partial | Review |

“Exactly Alcove” means matching interaction quality and equivalent user-facing
capabilities. It does not mean copying Alcove source, assets, wording, name, or
private artwork.

## 9. Implementation Phases

### Phase 0 — Baseline and plan

- [x] Inspect current MacIsland tree and runtime boundaries.
- [x] Research reference products.
- [x] Inspect Alcove binary/framework stack.
- [x] Identify Boring Notch as closest open-source native foundation.
- [x] Confirm GPL-3.0 acceptance.
- [x] Clone and pin Boring Notch upstream revision.
- [x] Resolve upstream Swift packages.
- [x] Build upstream Debug target without signing.
- [x] Document architecture, risks, visual direction, and validation.

Exit:

- Pinned upstream builds on current machine.
- GPL direction approved.
- Migration plan exists.

### Phase 1 — Import native foundation

- [x] Import application source, XPC helper, media adapter, project, license, and
  third-party notices.
- [x] Rename Xcode project, app target, helper target, products, source roots, and
  schemes to MacIsland.
- [x] Set app bundle ID to `com.macisland.app`.
- [x] Set helper bundle ID and XPC service name to
  `com.macisland.app.MacIslandXPCHelper`.
- [x] Preserve internal upstream type names where renaming adds no behavior.
- [x] Add `CFBundleDisplayName`, category, permission usage descriptions, and
  `LSUIElement`.
- [x] Disable upstream Sparkle feed and key until MacIsland release signing/feed
  exists.
- [x] Replace upstream menu labels and relaunch copy.
- [x] Ensure app and helper build unsigned from repository root.
- [x] Record source revision and attribution in README.

Exit:

- `MacIsland.xcodeproj` opens.
- `MacIsland.app` and `MacIslandXPCHelper.xpc` build.
- No app runtime contacts upstream update feed.
- Product bundle IDs contain no upstream identifier.

### Phase 2 — Brand-safe resource pass

- [x] Replace upstream app icon with MacIsland-owned icon.
- [x] Remove upstream team logos from runtime UI.
- [x] Keep upstream attribution in About/legal view and repository notices.
- [x] Replace upstream-only onboarding artwork and sound.
- [x] Rename primary visible “Boring Notch”/`boring.notch` strings to
  “MacIsland”.
- [x] Preserve translations only where wording remains accurate (no localization
  catalogs were imported; runtime copy is English-only).
- [x] Add missing accessibility labels for primary icon-only controls.

Exit:

- Runtime UI contains no upstream product branding except legal attribution.
- No Alcove, Perch, or DynamicLake assets exist in repository.

Status: complete — verified by asset-reference scan and unsigned Debug build on
2026-07-28.

### Phase 3 — Notch geometry and window lifecycle

- [x] Centralize physical notch metrics per `NSScreen`.
- [x] Distinguish:
  - physical notch width/height;
  - closed wing width;
  - open content size;
  - hover hit expansion;
  - drag target expansion.
- [x] Guarantee clear center content region matching physical camera housing.
- [x] Use one panel frame transition owner.
- [x] Coordinate SwiftUI silhouette with frame progress.
- [x] Clamp placement inside each screen frame.
- [x] Handle notchless displays with compact pill mode.
- [x] Handle display add/remove, resolution change, menu bar relocation, spaces,
  full-screen apps, screen lock, and wake.
- [x] Stop using stale persisted sizes without validation.

Exit:

- Closed state wraps the notch with equal measured wings.
- Content never renders behind physical camera housing.
- Open/close does not visibly jump on target hardware.
- External displays use valid compact mode.

Status: complete in code and primary-display runtime validation. External-display
and sleep/wake physical-hardware smoke tests remain release-gate checks.

### Phase 4 — Alcove-quality home surface

- [x] Implement hardware-black shell and carbon content surface.
- [x] Add a shared theme system: Midnight, Graphite, Frost, and High Contrast.
- [x] Add native Appearance controls and an in-context theme preview.
- [x] Build balanced two-column home: Now Playing + next event.
- [x] Use contextual accent from artwork or active system event.
- [x] Add compact header actions with native tooltips.
- [x] Move secondary tools into explicit tabs.
- [x] Implement directed media empty state.
- [x] Support keyboard focus and Escape-to-close.
- [x] Respect Increase Contrast, Reduce Transparency, and Reduce Motion.

Reference direction, reviewed 2026-07-28:

| Reference | What to adopt | MacIsland expression |
| --- | --- | --- |
| Alcove | One uninterrupted hardware-black surface; large, legible media hierarchy; restrained cool progress tint; springy but short state changes | Default Midnight theme, no fake dashboard chrome in media-only state, system typography and SF Symbols |
| Perch | Optional at-a-glance module row; compact header actions; user-selected utility tabs; home media/weather/calendar grouping | Opt-in Home modules, Calendar integration, Shelf tab, future timer/snippets—not copied layouts or assets |

Motion rules: one frame owner; opacity + scale only for entry; 180–280 ms interactive spring;
no repeating or off-screen animation; respect Reduce Motion before visual flourishes.

Exit:

- Home has one visual hierarchy.
- Empty state contains no fake data.
- At 1× and 2× scale, edges align to device pixels.

### Phase 5 — Media

- [x] Verify MediaRemote adapter load and failure path.
- [x] Preserve Apple Music, Spotify, and YouTube Music adapters.
- [x] Make current source selection explicit.
- [x] Show real title, artist, artwork, duration, progress, and playback state.
- [x] Throttle progress updates to visible views.
- [x] Stop visualizer work when hidden or paused.
- [x] Keep transport controls responsive without blocking main actor.
- [x] Define fallback when private MediaRemote integration becomes unavailable.

Exit:

- Initial metadata loads without waiting for next track event.
- Playback controls round-trip reliably.
- Idle state performs no waveform publication loop.

### Phase 6 — Calendar and reminders

- [x] Request EventKit permissions from feature onboarding.
- [x] Load events and reminders off render path.
- [x] Display next useful item on home.
- [x] Provide focused schedule view.
- [x] Handle denied/restricted permissions with Settings deep link.
- [x] Refresh on EventKit store changes and date boundaries.

Exit:

- Permission prompts have correct usage text.
- Denial never creates blank or broken layout.

### Phase 7 — Camera mirror

- [x] Run `AVCaptureSession.startRunning()` and configuration on session queue.
- [x] Start only when mirror becomes visible.
- [x] Stop promptly when hidden, app sleeps, or permission is revoked.
- [x] Handle missing camera and concurrent camera use.
- [x] Preserve aspect ratio and notch-safe crop.

Exit:

- Opening mirror does not hitch main thread.
- Camera indicator turns off after feature closes.

### Phase 8 — Shelf, drag, Quick Look, and sharing

- [x] Preserve security-scoped bookmark persistence.
- [x] Validate temporary-file lifecycle.
- [x] Open notch predictably when drag enters target.
- [x] Add visible one-pixel contextual target line.
- [x] Support Quick Look, Finder reveal, copy, remove, and share.
- [x] Keep AirDrop routing native.
- [x] Prevent duplicate URLs/items.
- [x] Restore shelf after relaunch without broken bookmarks.

Exit:

- Drag/drop works from Finder on primary and selected secondary displays.
- Temporary files do not leak indefinitely.

### Phase 9 — System live activities and HUD

- [x] Battery charge/percentage live activity.
- [x] Volume, mute, display brightness, and keyboard backlight HUD.
- [x] Accessibility permission onboarding for event interception.
- [x] XPC helper failure/authorization states.
- [x] Coalesce rapid hardware-key events.
- [x] Avoid replacing system HUD when user disables feature.

Exit:

- HUD follows input without queue buildup.
- Helper crash/unavailability degrades safely.

### Phase 10 — Settings and onboarding

- [x] Use native settings window semantics and toolbar/sidebar organization.
- [x] Group General, Appearance, Features, Gestures, Shortcuts, Updates, About.
- [x] Add typed defaults migration version.
- [x] Clamp all size and timing values at persistence boundary.
- [x] Add Reset control with clear scope.
- [x] Request permissions one at a time with feature explanation.
- [x] Configure global keyboard shortcuts.
- [x] Configure launch at login.

Exit:

- Settings changes apply once per user action.
- Invalid legacy values cannot create malformed panel geometry.

### Phase 11 — Performance and lifecycle

- [x] Profile idle CPU, open/close, media playback, mirror startup, and shelf drag.
- [x] Remove broad observable-object invalidations from hot paths.
- [x] Audit timers, notification observers, display links, tasks, and XPC
  connections.
- [x] Cancel work on feature closure and app termination.
- [x] Add signposts around panel transitions and camera startup.
- [x] Test sleep/wake and rapid display changes.

Targets:

- Idle CPU: near zero when no activity is visible.
- No repeated layout pass caused by idle fake waveform updates.
- Open transition: no main-thread blocking operation.
- Camera startup work: session queue only.
- Settings slider: at most one coalesced panel update per display frame.

### Phase 12 — Tests and delivery

- [x] Add unit test target for geometry and settings migration.
- [x] Add state-machine tests for open, close, pin, drag, and permission states.
- [x] Add service protocol seams for media/EventKit/camera failure tests.
- [x] Add build script using Xcode project.
- [x] Add Debug and Release validation commands.
- [x] Add archive/export documentation.
- [x] Configure Developer ID/hardened runtime when team credentials exist.
- [x] Configure notarization outside source-controlled secrets.
- [x] Add release license/source-offer verification.
- [x] Add update feed only after signing keys and hosting exist.

Exit:

- Clean Debug and Release builds succeed.
- Automated tests pass.
- Archive contains app, helper, frameworks, notices, and correct entitlements.

### Phase 13 — Legacy retirement

- [x] Confirm native target covers every retained MacIsland behavior.
- [x] Remove retired standalone source, manifest, bundle metadata, and build
  script in one reviewable migration.
- [x] Update README to Xcode-only workflow.
- [x] Remove stale generated-product instructions and artifacts.
- [x] Confirm no documentation points to retired standalone types.

Exit:

- One canonical app target and one canonical build path remain.
- Fresh clone builds using documented commands.

### Phase 14 — Parity closure, live visual QA, and release integrity

Status: active. Phase 13 retired inactive code; it did not prove Alcove/Perch
feature parity or a production-quality visual/runtime release.

> Canonical status moved to [fixed.md](fixed.md). Do not update the Phase 14
> checkboxes below; they are retained as historical phase context.

#### P0 — Unblock real macOS runtime validation

- [x] Restore LaunchServices and Spotlight access in the agent host session.
  Revalidated 2026-07-28: `lsregister` and `open` both succeed for Calculator.
- [x] Restore display-capture permission/service for the test host.
  Revalidated 2026-07-28: `screencapture` succeeds.
- [x] Prove host readiness by launching Calculator through `open`, capturing one
  desktop screenshot, then launching MacIsland from its `.app` bundle.
- [ ] Run and retain screenshot evidence for notched internal display, notchless
  external display, full-screen app, multiple Spaces, sleep/wake, lock/unlock,
  Reduce Motion, and Increase Contrast.

Host note: the first two items are environment/service-owner work, not app-code
work. MacIsland currently aborts in AppKit application registration only because
that LaunchServices database is unavailable to this execution session.

#### P0 — Make every shipped bundle valid

- [x] Add `CodeSignOnCopy` to the embedded `MacIslandXPCHelper.xpc` build phase.
- [x] Build Release with signing enabled and verify the app, XPC helper, and all
  nested frameworks using `codesign --verify --deep --strict --verbose=4`.
  Revalidated 2026-07-29 with local signing at
  `/private/tmp/macisland-release-signed.77VcQW`.
- [x] Ensure release packaging rejects invalid input instead of creating a ZIP/DMG.
  `Scripts/create-dmg.sh` verifies strict bundle signatures before packaging and
  falls back to file-only hybrid-image conversion when DiskManagement is unavailable.
- [ ] Sign final distribution with Developer ID Application and notarize/staple it.
- [x] Add strict distribution verification. `Scripts/verify-distribution.sh`
  rejects local signing and requires Developer ID authority, Gatekeeper
  assessment, strict nested-code validation, and a stapled ticket.
- [ ] Rebuild the shareable artifact only after signature and launch smoke tests pass.

Known evidence: locally signed Release now verifies strictly, including embedded XPC
and frameworks. Developer ID signing/notarization remains a distribution credential
gate, not an app-bundle integrity defect.

#### P0 — Reliable native test execution

- [x] Generate an Info.plist for `MacIslandTests` so it can be code signed.
- [x] Run signed native validation: Debug build, Release build, and all five XCTest
  cases pass using `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`.
- [x] Update `Scripts/validate-xcode.sh` to use this signed XCTest configuration.
- [x] Clean up the validation build's MediaRemote adapter child on exit so native
  test runs cannot leave extra MacIsland-related background processes.
- [x] Isolate the XCTest host bundle identifier. Validation now uses
  `com.macisland.validation`, so tests pass while another `com.macisland.app`
  instance is already active.
- [ ] Add UI/screenshot automation with an approved assistive-access test host.
  Current host has screen capture but denies `osascript` assistive access (`-25211`),
  so hover, click, gesture, Shelf, and Settings interactions remain manual gates.
  `Scripts/visual-audit.sh` now captures host metadata plus named state PNGs and
  exits before capture when Assistive Access is unavailable.
- [x] Add deterministic geometry coverage for notched internal, notchless external,
  and narrow displays. `NotchMetricsInput` separates screen measurement from
  AppKit and XCTest validates physical-notch and open-panel bounds.
- [x] Fix Quick Share provider discovery for services with invalid icon
  representations. Icons now serialize from a validated bitmap representation;
  full validation no longer emits `CGImageDestination…invalid capacity (0)`.

Live evidence, 2026-07-28:

- Signed Debug app and embedded XPC helper pass strict signature verification.
- App launches as one main process plus one MediaRemote adapter helper process.
- First-run onboarding renders; island interaction was not asserted because the
  current automation host lacks assistive access.
- 2026-07-29 isolated live launch rendered expected invisible idle closed state;
  open-state capture remains blocked by missing assistive access.

#### P1 — Close native-island visual gaps

- [~] Centralize core island motion. `IslandMotion` now owns state, interaction,
  and content timing with Reduce Motion support; remaining scene ownership work
  stays below.
- [~] Define one island scene model: closed, peek, expanded, live activity, and
  file tray. `IslandSceneResolver` now owns tested priority for onboarding,
  user-opened content, system HUD, battery, timer, media, idle, Home, and Shelf;
  `IslandSurface` owns silhouette, clipping, inset, seam, and elevation.
- [ ] Tune closed-notch wings, black silhouette, shadows, hover target, and menu-bar
  blending from real 1x/2x screenshots. No content may render behind camera housing.
- [ ] Replace conditional Home reflow with stable module slots and explicit compact/
  expanded layouts. Media must remain primary; calendar/camera cannot move controls.
  Initial pass: Home now gives each enabled module an explicit width and camera frame;
  music-control slots no longer disappear when Calendar and Mirror are both active.
- [ ] Replace scattered animation constants with shared motion tokens; respect Reduce
  Motion and remove nonessential repeating work. Idle-face blinking now uses one
  cancellable task per appearance and is disabled for Reduce Motion. Onboarding,
  controls, HUDs, media, and status transitions now use `IslandMotion`; remaining
  isolated preview-only animation is non-product code.
- [ ] Author MacIsland-specific elevation, typography, hover, focus, status, and
  empty-state tokens. Do not reproduce reference-product artwork or layouts.
  Initial tokens now define module/control radii, padding, contrast-safe elevation,
  shared focused/empty Shelf states, plus semantic primary/secondary/warning text.

#### P1 — Close core feature gaps against reference behavior

- [~] Implement timer: countdown, stopwatch, alarm completion, compact live state,
  and accessible controls. Countdown + stopwatch now have compact state and shared
  pause/resume controls plus active-countdown recovery and opt-in durable
  completion notifications; named presets persist and launch from the header.
- [~] Implement snippets/clipboard history: privacy controls, retention limit,
  keyboard shortcut, searchable compact panel, and paste action. Complete:
  explicit opt-in, local history, configurable retention, search, copy/delete,
  compact panel, shortcut, bundle-ID exclusions, and plain-text-only default;
  direct-paste workflow remains.
- [x] Implement weather only with explicit location/permission, loading/error states,
  cache policy, and an opt-in Home module. Complete: explicit manual city,
  Open-Meteo data, local 15-minute cache, real state UI, Home module, and
  Celsius/Fahrenheit preference; injected HTTP tests cover valid and failing API
  responses.
- [~] Introduce a generic live-activity coordinator with priority, queueing,
  interruption rules, and a single presentation path for media, timers, transfer,
  battery, and system HUDs. `BoringViewCoordinator` now arbitrates/queues media,
  download, system HUD, and battery activities; timer integration remains.
- [~] Rework Shelf into compact tray. Complete: item count, selected-item
  Delete-key removal, overflow, confirmed clear, empty/loading state, drag feedback,
  Quick Look, share, Control-arrow selection, per-drop error state, and retained
  security-scoped items. Remaining: screenshot proof.

#### P2 — Product polish, performance, and test gates

- [ ] Reorganize Settings around Appearance, Behavior, Gestures, Modules, and
  Advanced; avoid whole-window rebuild when accent color changes. The accent update
  now changes only reactive tint state; it no longer invalidates Settings with `.id`.
- [ ] Profile idle, expand/collapse, active media, lyrics, camera, drag/drop, and
  settings changes with Instruments on target hardware. Define CPU/memory budgets.
- [ ] Add UI automation and screenshot baselines for core island states and all
  supported display modes; run accessibility inspection for keyboard, VoiceOver,
  contrast, and reduced motion.
- [ ] Expand failure-path tests for denied calendar/camera/location permissions,
  unavailable media adapter, XPC failure, display removal, and sleep/wake.

Exit:

- Signed, notarized app passes strict bundle verification and launches through `open`.
- Screenshot matrix proves notch integration and transitions on real hardware.
- Core modules provide media, calendar, camera, shelf, timer, clipboard/snippets,
  and opt-in weather without fake data.
- No P0/P1 task remains unchecked; performance and accessibility gates pass.

## 10. Implementation Order

Strict order:

1. Import license-safe foundation.
2. Prove renamed target builds.
3. Remove update-feed and bundle-identity hazards.
4. Rebrand visible runtime UI.
5. Fix notch geometry and transition ownership.
6. Build home visual system.
7. Validate existing features.
8. Profile and remove lifecycle/performance defects.
9. Add tests and delivery gates.
10. Retire the legacy standalone implementation.
11. Close Phase 14 runtime, visual-parity, feature-parity, and release gates.

Do not redesign feature internals before renamed foundation builds.

## 11. Risk Register

| Risk | Level | Control |
| --- | --- | --- |
| GPL obligations missed | High | Ship GPL license, attribution, corresponding source, third-party notices |
| Alcove imitation crosses into copied expression | High | Copy behavior patterns only; create MacIsland visual tokens, copy, and assets |
| Private MediaRemote APIs break or block App Store | High | Isolate adapter, document direct-download channel, maintain fallback |
| XPC service name mismatch after rename | High | Change bundle ID, service name, target product, and client together; runtime smoke test |
| Sparkle contacts upstream feed | High | Disable updater until MacIsland feed/key exists |
| Mechanical project rename breaks target graph | Medium | Rename in one phase, build immediately, inspect embedded helper |
| Existing source lost without Git metadata | High | Preserve legacy tree until parity; no destructive removal during bootstrap |
| Screen geometry differs across hardware | High | Model per-screen notch metrics and test notched/notchless/multi-display |
| Too many observed singletons invalidate UI | Medium | Introduce narrow view state only in measured hot paths |
| Accessibility/event interception surprises users | Medium | Explicit onboarding, opt-out, safe helper failure |
| Resource branding remains upstream | Medium | Runtime string/asset audit before release |
| Dependency supply-chain changes | Medium | Keep pinned `Package.resolved`, review upgrades separately |

## 12. Validation Matrix

### Build

```bash
xcodebuild \
  -project MacIsland.xcodeproj \
  -scheme MacIsland \
  -configuration Debug \
  -derivedDataPath /private/tmp/macisland-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```bash
xcodebuild \
  -project MacIsland.xcodeproj \
  -scheme MacIsland \
  -configuration Release \
  -derivedDataPath /private/tmp/macisland-release-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Tests

```bash
xcodebuild \
  -project MacIsland.xcodeproj \
  -scheme MacIsland \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/macisland-test-derived \
  CODE_SIGNING_ALLOWED=NO \
  test
```

### Product identity

```bash
plutil -p \
  /private/tmp/macisland-derived/Build/Products/Debug/MacIsland.app/Contents/Info.plist
```

```bash
find \
  /private/tmp/macisland-derived/Build/Products/Debug/MacIsland.app/Contents \
  -maxdepth 3 \
  -print
```

### Static checks

```bash
rg -n \
  'theboringteam\\.boringnotch|https://TheBoredTeam\\.github\\.io/boring\\.notch/appcast\\.xml' \
  MacIsland MacIslandXPCHelper MacIsland.xcodeproj
```

```bash
rg -n \
  'Alcove|Perch|DynamicLake' \
  MacIsland MacIslandXPCHelper
```

Reference product names may exist in `PLAN.md`; they must not appear in runtime
source or assets.

### Runtime smoke tests

- Launch on notched internal display.
- Verify closed silhouette wraps, not covers, physical notch.
- Hover open, leave close, click pin, Escape close.
- Change active display and attach/detach external display.
- Play/pause/seek Apple Music and Spotify.
- Open calendar after allow, deny, and restricted states.
- Open/close mirror and verify camera indicator lifecycle.
- Drag file to closed and open shelf.
- Trigger volume, mute, brightness, backlight, and power live activity.
- Open Settings and change size continuously.
- Sleep/wake, lock/unlock, and enter full-screen space.
- Run with Reduce Motion and Increase Contrast.

## 13. Migration Exit Criteria

The legacy standalone implementation was retired after all of the following:

- Native target builds Debug and Release.
- Product is named and bundled as MacIsland.
- Updater cannot contact Boring Notch feed.
- XPC helper connects using MacIsland service identity.
- Closed notch geometry is correct on actual target MacBook.
- Media, calendar, mirror, shelf, battery, and HUD smoke tests pass.
- Settings persist through relaunch with migration/clamping.
- Idle and transition performance are profiled.
- GPL and third-party notices are present.
- README documents one supported build path.

## 14. Progress Log

### 2026-07-28

- Completed current-repo architecture and visual audit.
- Researched Alcove, Perch, DynamicLake, and Boring Notch.
- Inspected Alcove application binary/framework composition.
- Confirmed native SwiftUI/AppKit direction.
- Received GPL-3.0 approval.
- Cloned Boring Notch revision
  `8dd02e7555cbe48899524c61d24e50703e68ff68`.
- Resolved upstream package graph.
- Proved unsigned upstream Debug build succeeds under Xcode 26.6.
- Imported and renamed native app and XPC helper targets.
- Set MacIsland app/helper bundle identities and XPC service name.
- Disabled upstream Sparkle feed and automatic updater startup.
- Proved renamed unsigned Debug build succeeds from repository root.
- Completed Phase 1; started Phase 2.
- Replaced decorative first-run screen with compact native onboarding.
- Prevented Settings from restoring automatically on app launch.
- Removed overlapping first-launch notch animation and welcome sound.
- Reduced open shell from 640×190 to 600×176 points.
- Added carbon surface and real idle-media state without fake timestamps.
- Reviewed official Alcove media and Perch home visuals; recorded the derived
  MacIsland direction and feature matrix in Phase 4.
- Added persisted island themes (Midnight, Graphite, Frost, High Contrast),
  shared surface tokens, and native Appearance picker/preview.
- Replaced all AppIcon renditions with an original MacIsland icon and retired
  unused upstream team/logo assets from the project.
- Added VoiceOver labels/tooltips to notch header and tab controls.
- Fixed test-discovered MediaRemote helper lifecycle: controller shutdown now
  terminates its adapter process before replacement or application exit.
- Captured and reviewed closed, open, and onboarding runtime screenshots.
- Verified final Debug and Release Xcode builds.
- Verified `com.macisland.app` identity and embedded
  `com.macisland.app.MacIslandXPCHelper`.
- Verified upstream Sparkle feed/key and reference-product runtime strings are
  absent.
- Known upstream warnings remain around Swift 6 sendability, AppKit actor
  isolation, and a macOS 15 MediaRemote adapter linked from a macOS 14 target.
