# MacIsland parity and native-experience closure ledger

Status: active audit — 2026-07-29

## Benchmark boundary

Alcove and Perch are behavior and quality references only. MacIsland must not
copy their artwork, copy, branded layout, or assets. It must exceed them with a
quieter, more reliable, privacy-respecting native macOS experience.

Visual-direction priority (user-confirmed 2026-07-29): perceived polish and
interaction quality comparable to Perch, Dynamic Lake, and Alcove take priority
over adding more feature breadth. The target qualities are a continuous
hardware-black silhouette, compact information hierarchy, subtle
content-derived light, quiet glass layers, restrained controls, and fluid
notch-origin motion. MacIsland must express those qualities with its own
composition, semantic tokens, copy, and artwork.

## Definitive capability brief

The user-supplied 2026-07-29 reference establishes the following desired
end-user capabilities. It is a behavior/completeness reference, not permission
to copy the source product's artwork, wording, or exact layouts.

| Capability | Current status | Public-native acceptance boundary |
| --- | --- | --- |
| Full media player with Playing Next | [~] | Current track, progress, transport, volume, artwork, and visualizer exist. Add a real provider-backed queue only where the selected media provider exposes queue data; never fabricate upcoming tracks. |
| Volume and brightness HUDs | [x] | Existing notch-safe volume, display-brightness, and keyboard-brightness HUDs remain the MacIsland treatment. |
| Native AirPlay and audio-output picker | [ ] | Use an Apple-provided route/output picker and accurately describe the playback it controls. `AVRoutePickerView` routes media owned by its player; it must not be presented as a system-wide router for Spotify, Music, or another process. |
| Voice recordings with transcription | [ ] | Add opt-in microphone recording and Speech transcription with visible recording state, permission-denied behavior, local retention controls, playback, rename, export, and delete. |
| VPN status with session timer | [ ] | Support a MacIsland-managed Personal VPN configuration when the required entitlement and configuration exist. Public `NEVPNManager` does not provide a universal monitor for arbitrary third-party VPN clients. |
| Calendar and reminders with natural-language entry | [~] | Calendar/reminder reading, display, and reminder completion exist. Add explicit user-confirmed natural-language creation through EventKit; never modify the event store without confirmation. |
| Live motion artwork | [~] | Spectrum and custom visualizers exist. Add an artwork-derived, Reduce-Motion-safe presentation without copying the reference animation. |
| Claude, Codex, and Cursor progress | [ ] | Add opt-in adapters for documented/local integration points with source attribution, bounded activity lifetime, failure/idle states, and no screen scraping or credential capture. |
| Battery alerts with Low Power action | [~] | Battery, charging, and Low Power state alerts exist. The public API exposes Low Power Mode as read-only, so the action may open the correct Battery setting but must not claim to toggle the mode directly. |
| Inline WhatsApp and Messages replies | [ ] | Do not impersonate another app's notification action or acquire broad keyboard/Accessibility control. Only ship when a provider-supported reply integration exists; otherwise offer an honest Open action. |
| Timers synchronized with Apple Clock | [~] | Native MacIsland countdown, stopwatch, recovery, presets, and notifications exist. No public Clock timer database/API is available to claim two-way synchronization; retain MacIsland ownership unless Apple exposes one. |
| Recent notifications in Shelf | [ ] | Public UserNotifications APIs can retain only MacIsland's delivered notifications. Do not read Notification Center databases or scrape other apps; provide app-owned activity history only unless a source explicitly shares records. |

These boundaries are acceptance criteria, not optional downgrades: unavailable
cross-app data must produce an honest unsupported/empty state rather than a
simulated feature, private database access, or silently expanded
Accessibility/keyboard authority.

## Evidence reviewed

- [Perch App Store listing](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12): Home media/weather/camera/calendar,
  countdown + stopwatch, snippets/recent copies, temporary File Tray, and
  notchless-Mac adaptation.
- [Alcove profile](https://appstacks.club/alcove): subtle animated HUD for music,
  now playing, weather, and custom visuals; SwiftUI implementation.
- [Alcove maker interview](https://medium.com/@teslathewest/the-story-behind-alcove-macos-dynamic-island-app-dadb5d97e8b0): passive fade-in/fade-out,
  lock-screen integration, and system-change-driven HUDs without unnecessary
  keyboard permissions.

## Current MacIsland result

- Native SwiftUI/AppKit notch panel with physical-notch metrics and notchless
  fallback; media, calendar, camera mirror, battery/HUD, Shelf, Quick Look, and
  Quick Share.
- Countdown, stopwatch, presets, recovery, and opt-in completion notification.
- `IslandSurface` owns silhouette geometry; `IslandSceneResolver` owns tested
  presentation priority.
- Shared motion/tokens, Reduce Motion behavior, cancellable idle animation, and
  stable Home module budgets.
- Debug/Release validation passes with 43 XCTest cases.

## Live-run limits

- Current host has one 3024×1964 Retina internal display at 1512×982 points
  (native 2x only).
- Screen capture and window/control Assistive Access work; System Events can
  inspect and press MacIsland controls.
- A 1x display plus external displays, full-screen state preparation, Spaces,
  sleep/wake, lock/unlock, contrast, and the remaining visual comparison matrix
  remain unproven.

## Required fixes — priority order

This is the canonical parity/release ledger. All Phase 14 parity-closure boxes
from `PLAN.md` are merged here. Update this file only for parity status.

### 1. P0 — runtime validation and visual proof

1.1 [x] LaunchServices and Spotlight access restored; `lsregister` and `open`
launch Calculator.

1.2 [x] Display capture service available; `screencapture` succeeds.

1.3 [x] Host smoke proved: Calculator launched through `open`, desktop capture
succeeded, then MacIsland launched from its app bundle.

1.4 [x] Deterministic notched, notchless, and narrow-display geometry coverage
exists through `NotchMetricsInput` and XCTest physical-notch/panel bounds. On
2026-07-29, notchless metrics were made explicit as a centered 160-point
synthetic island with no physical camera geometry; legacy non-notch height
settings safely map to menu-bar height. The physical-notch branch remains
separate and is covered by the same XCTest. `Scripts/validate-xcode.sh` passed
Debug/Release builds and 41 XCTest cases with 0 failures.

1.5 [x] [visual-audit.sh](Scripts/visual-audit.sh) captures named-state PNGs plus
display/software metadata and refuses noninteractive or non-AX runs.

1.6 [x] Assistive-Access UI-test host approved. Evidence (2026-07-29):
`osascript -l JavaScript -e 'Application("System Events").processes.byName("Finder").windows.length'`
returned `1`, proving System Events can inspect Finder windows.

1.7 [~] Retained and reviewed native-2x closed, Home, and Shelf-empty captures
with display/software metadata in `Audit/2026-07-29-retina-2x/` (2026-07-29).
Fresh reviewed closed (`20260729-015102-closed.png`) and Home
(`20260729-014923-home.png`) captures reconfirm the state after timer work.
Closed shows hardware-black integration; Home shows media/calendar; Shelf shows
its empty state. Timer paused-state capture (`20260729-014120-timer.png`) shows
`0:59 Resume` below the physical camera housing; completed-state capture
(`20260729-014744-timer.png`) shows `Time's up · Done` in the same compact
surface. Remaining: all 1x
captures and 2x hover, media,
battery/HUD, calendar, camera, drag/drop, Reduce Motion, and Increase Contrast
captures; current host has no 1x display and cannot supply every required live
activity/permission state.

1.8 [~] Current internal display is notched (`NSScreen.safeAreaInsets.top == 32`)
and native 2x; its closed/Home/Shelf evidence is retained under
`Audit/2026-07-29-retina-2x/`. Fresh full-screen Code proof (2026-07-29): Code
reported `AXFullScreen=true`, while reviewed native-2x capture
`20260729-015206-home.png` visibly shows MacIsland Home above Code. Code was
restored and reported `AXFullScreen=false`. Remaining: full matrix on a
notchless external display, all required states in full screen and Spaces, and
sleep/wake/lock/unlock proof. Current host has only one internal 2x display.

1.9 [x] Closed bridge geometry now uses a fixed 4 pt wing per side of the
physical housing (208 × 32 pt housing, 216 × 32 pt surface), independent of
corner radii; its invisible hover frame is separately bounded and tested.
`IslandSurface` uses semantic hardware/shadow tokens, keeps the collapsed bridge
clear, and leaves active-content sizing unchanged. XCTest
`testClosedBridgeAndHoverTargetStayOutsideThePhysicalCameraGeometry` verifies
the 2× notched dimensions and hover edges. Fresh, reviewed native-scale
captures with adjacent display/software metadata: closed
`20260729-015915-closed.png`, left-wing hover
`20260729-015916-hover.png`, and left-wing click/Home
`20260729-015918-home.png`. The closed surface blends with the menu bar; both
hover and click reach Home without visible camera-housing content. Full
`Scripts/validate-xcode.sh` passed (Debug/Release, signed XCTest, entitlement
and branding checks).

### 2. P0 — signed distributable bundle

2.1 [x] `CodeSignOnCopy` configured for embedded `MacIslandXPCHelper.xpc`.

2.2 [x] Local signed Release verifies app, XPC helper, and nested frameworks with
`codesign --verify --deep --strict --verbose=4`.

2.3 [x] Packaging rejects invalid input; DMG packaging has sandbox-safe fallback.

2.4 [x] [verify-distribution.sh](Scripts/verify-distribution.sh) requires strict
nested-code validation, Developer ID authority, Gatekeeper assessment, and a
stapled ticket.

2.5 [~] External release-credential blocker confirmed 2026-07-29:
`security find-identity -v -p codesigning` returned `0 valid identities found`;
the project has an empty `DEVELOPMENT_TEAM`. A locally built Release app also
has `TeamIdentifier=not set`, so it cannot meet the Developer ID gate. No
certificate, private key, App Store Connect credential, profile, or notarization
secret was created or stored in source control. Remaining: install the valid
Developer ID Application certificate and its private key in the release keychain
(and provide notarization authorization there or in release CI), then archive,
notarize, staple, and run `Scripts/verify-distribution.sh /path/to/MacIsland.app`.

2.6 [~] Blocked by 2.5 as of 2026-07-29. The host has no Developer ID identity
(`security find-identity -v -p codesigning` → `0 valid identities found`) and
no notarized MacIsland archive, app, or DMG is available. No local/ad-hoc app
was misrepresented as notarized; launch smoke and DMG rebuild/share were not
run. Remaining: make a Developer ID-signed, notarized, stapled MacIsland app
available after 2.5 passes, then launch-smoke that exact app and rebuild/share
its DMG.

### 3. P0 — reliable native test execution

3.1 [x] Code-signed `MacIslandTests` has generated Info.plist support.

3.2 [x] Validation builds Debug/Release, then runs signed XCTest with isolated
bundle ID `com.macisland.validation`.

3.3 [x] Validation cleans temporary MediaRemote adapter child on exit.

3.4 [x] Quick Share provider discovery handles invalid icon representations.

3.5 [~] Approved native UI baseline harness added. `prepare-ui-audit-state.sh`
uses already-granted Assistive Access to prepare closed, Home, and hover from
active-display points, while `visual-audit.sh` now waits for and requires a real
MacIsland accessibility window before it can capture. The native-2× notched
baseline manifest records closed, Home, Shelf, and timer PNGs with SHA-256,
3024 × 1964 dimensions, and adjacent display/software metadata;
`Scripts/verify-ui-baselines.sh Audit/Baselines/native-2x/manifest.plist`
passes. Fresh automated closed and Home captures were visually inspected on the
Debug app; full `Scripts/validate-xcode.sh` passed (21 XCTest cases). Remaining:
approved 1× and notchless/external-display hardware is unavailable, so those
display-mode baselines and richer live media/battery/HUD/camera action drivers
remain unproven.

### 4. P1 — native-island visual closure

4.1 [~] `IslandMotion` now owns state, interaction, content, and onboarding
timing, with one explicit policy for nonessential motion. Marquee text resets
instead of starting its repeating scroll under Reduce Motion; the spectrum
stops its timer immediately and observes accessibility-display changes; the
onboarding snake finishes without running. XCTest
`testReduceMotionPolicyStopsNonessentialVisualWork` verifies the policy and
spectrum lifecycle. Fresh native-2x Home capture
`20260729-021500-motion-home.png` (with adjacent display/software metadata)
was reviewed after the change; it remains physically notch-safe and compact.
`Scripts/validate-xcode.sh` passed Debug/Release, signing checks, and 22 XCTest
cases (2026-07-29). Remaining: approved live Reduce Motion screenshot capture;
the System Settings Display pane did not render a usable lower control after
UI scrolling on this host, so the preference was not changed or misreported.

4.2 [~] `IslandSurface` owns physical silhouette; `IslandSceneResolver` owns
tested user-opened content > battery > HUD > timer > media > idle priority.
The header now reserves equal fixed side lanes around the measured physical
bridge, so Home and Shelf tab/action content cannot redefine the ledge width or
vertically displace the island. The expanded surface also restores the semantic
`islandBorder` outline without drawing through the closed hardware bridge.
`Scripts/validate-xcode.sh` passed Debug/Release, signing checks, and 41 XCTest
cases (2026-07-29). A reviewed native-2× Shelf capture
`interaction-polish/20260729-101220-header-stable-shelf.png` and
`interaction-polish/20260729-101500-home-control-check.png` confirm the same
centered bridge and separated control lanes in Shelf and Home. Remaining:
cross-display screenshot acceptance. The header control strip was then reduced
to immediate Timer, direct Settings, and optional battery status: camera mirror
stays in Home, while Settings is a plain gear button rather than a second-row
overflow affordance. The Settings-button preference is restored as “Show
Settings button in island.” Full `Scripts/validate-xcode.sh` passed (41 XCTest
cases, 2026-07-29); the final direct-settings build also passed. Remaining:
cross-display screenshot acceptance and a clean no-media header recapture.

4.3 [x] Closed notch tuning is complete on the native 2× notched display. The
rendered bridge remains a silent 216 × 32 pt hardware-black silhouette around
the 208 × 32 pt physical housing, while the optional transparent hover target
now reaches the actual SwiftUI surface (276 × 62 pt when enabled) rather than
only existing in metrics. `testClosedBridgeAndHoverTargetStayOutsideThePhysicalCameraGeometry`
checks both default and extended bounds. Fresh reviewed captures, with adjacent
display/software metadata: closed `20260729-022000-closed-tuned.png` has no
menu-bar seam; left-wing hover `20260729-022010-wing-hover.png` opens Home from
the transparent target without camera-housing content. Focused XCTest and full
`Scripts/validate-xcode.sh` passed (22 XCTest cases, 2026-07-29).

4.4 [x] `HomeLayoutBudget` now gives media the residual fixed slot, admits
Calendar only when it fits as the secondary module, and bounds the mirror to a
square 112 pt slot (or omits it before it can crowd controls). Narrow 296 pt
layouts retain media alone; weather reserves vertical room. Camera preview now
has an explicit VoiceOver label/value. XCTest
`testHomeLayoutBudgetKeepsMediaPrimaryAndBoundsOptionalModules` covers
media/calendar/camera, weather, narrow, and short layouts. Fresh reviewed
native-2× Home capture `20260729-022500-home-budget.png` shows working media
controls primary and Calendar secondary, both below the physical housing.
Activating the visible camera control reached the real macOS prompt, “Allow
MacIsland to access your camera?”, with the app’s visible-only explanation.
The user authorized it on 2026-07-29; reviewed native-2× capture
`permission/20260729-025150-camera-activated.png` shows the bounded Home mirror
slot while macOS’s green camera-use indicator is active. `showMirror` was
restored to its prior off value after testing. The prior compact-media capture
did not visibly expose an island; fresh reviewed native-2× capture
`interaction-polish/20260729-102400-home-inset-rounded.png` now shows Home
with its rounded media module below the header. `Scripts/validate-xcode.sh`
passed Debug/Release and 23 XCTest cases (2026-07-29). Home now reserves a 12 pt top
inset below the physical bridge and renders its media module with the same
rounded semantic surface and border used by Shelf, preventing the prior sharp,
screen-edge collision. The layout budget subtracts that inset before admitting
optional modules; the focused XCTest passed (2026-07-29).

4.5 [~] Production transitions use shared motion; idle animation is cancellable.
Removed the unused `BoringAnimations`/bouncy Shelf transaction and routed the
remaining onboarding completion through `IslandMotion`. The idle face now
cancels and resets without animation when hidden or when Reduce Motion changes;
the onboarding task also exits after cancellation instead of reviving a hidden
view. The root island container no longer disables its `notchState` animation,
so close uses `IslandMotion.state` instead of collapsing in a single render
pass. `testIdleFaceMotionStopsWhenHiddenOrReduceMotionIsEnabled` and the full
`Scripts/validate-xcode.sh` gate passed (Debug/Release, signed XCTest, 41 cases,
2026-07-29). Reviewed native-2× Assistive-Access captures
`4.5-motion-resolved/20260729-025500-closed.png` and
`4.5-motion-resolved/20260729-025505-home.png` now prove the unobstructed
closed/open endpoints after camera consent. Remaining: direct frame-sequence
evidence of the revised close motion and a Reduce Motion capture of the same
transition behavior.

4.6 [~] `IslandPalette` now resolves theme plus system Increase Contrast into
surface, elevation, border, primary/secondary/disabled text, pressed, focus,
track, scrim, positive/critical, and warning tokens. `IslandTypography` provides
the shared title/body/metadata/control roles. Island-facing Content, Home,
Calendar, Shelf, camera placeholder, HUD, battery, visualizer, and theme preview
now consume those tokens; remaining literal colors are central palette values,
user-selectable accent swatches, image processing, or native Settings semantics.
`testIslandPaletteElevatesContrastForThemeAndSystemPreference` proves normal,
theme-high-contrast, and system-high-contrast policy. Focused XCTest and the full
`Scripts/validate-xcode.sh` gate passed (Debug/Release, signed XCTest, 25 cases,
2026-07-29). Reviewed unobstructed native-2× Home capture
`4.5-motion-resolved/20260729-025505-home.png` verifies the refreshed normal
token surface. Remaining visual proof: an Increase Contrast capture.

### 5. P1 — feature parity closure

5.1 [~] Timer has countdown, stopwatch, presets, recovery, completion attention,
and completion notifications enabled by default (user may disable them). Timer
notification scheduling now cancels stale asynchronous authorization work on
pause/stop/restart, and foreground completion explicitly requests native banner,
list, and default-sound presentation. The resolved closed-island policy is
`battery > completed timer > system HUD > active timer > media`; a completed
timer persists until Done, while an interrupted active timer reappears after the
HUD ends. XCTest `testCountdownCompletionPersistsUntilDismissed`,
`testIslandSceneResolverKeepsUserAndCriticalActivityPriority`, and
`testTimerNotificationUsesStableIdentifierAndNativeContent` cover those paths.
Reviewed native-2× captures in `5.1-timer/`: `20260729-025645-timer-running.png`
shows Start 1 minute collapse Home to compact `1:00 Pause`; both
`20260729-025830-timer-completed.png` and
`20260729-030225-timer-foreground-completed.png` show `Time's up · Done` below
the physical housing. `Scripts/validate-xcode.sh` passed Debug/Release,
entitlement/branding checks, and 26 XCTest cases (2026-07-29). Remaining
external proof: this host did not show a notification consent sheet, did not add
MacIsland to System Settings > Notifications, and showed no banner/audio during
two real one-minute runs despite foreground delivery being requested. Enable
notifications for the released, user-installed MacIsland bundle (banners +
sound), then repeat one completion capture; this Debug host cannot establish
system delivery or audio proof.

5.2 [~] Snippets has opt-in local-only retention, limit, dedupe, case-insensitive
search, plain-text default, rich-text opt-in, excluded bundle IDs, copy/delete,
clear, empty/off states, compact tab, and configurable `Show Snippets` shortcut.
Copy now explicitly says `Copied` and writes only to the system pasteboard; it
does not synthesize a paste. XCTest `testClipboardHistoryIsOptInAndDeduplicated`,
`testClipboardPrivacyFiltersAppsAndRichContent`,
`testCopyClipboardEntryWritesPlainTextWithoutCapturingIt`, and
`testClipboardSearchTrimsAndMatchesCaseInsensitively` cover retention, privacy,
copy, and search. Reviewed native-2× captures `5.2-snippets/20260729-030750-snippets-captured.png`
and `5.2-snippets/20260729-030756-snippets-copied-settled.png` prove an actual
opt-in pasteboard capture, compact search/list presentation, and `Copied`
confirmation; `pbpaste` returned the exact selected snippet. Full
`Scripts/validate-xcode.sh` passed Debug/Release, entitlement/branding checks,
and 28 XCTest cases (2026-07-29). Remaining intentionally unimplemented:
paste-into-previous-app needs broad Accessibility/keyboard authority, forbidden
by the project privacy rule; user can paste explicitly after Copy.

5.3 [x] Weather has manual city, Open-Meteo data, cache, unit preference, real
states, and injected success/failure tests. Cache reuse now requires the same
normalized city, and in-flight refreshes are cancelled/ignored when superseded
or disabled. XCTest `testWeatherCacheUsesOnlyTheCurrentCityWithinItsLifetime`
plus injected Open-Meteo success/failure tests passed (2026-07-29). Reviewed
native-2× Home capture `20260729-031450-weather-home.png` visibly shows
“Austin · 81°F · Partly cloudy”. Full `Scripts/validate-xcode.sh` passed
Debug/Release, entitlement/branding checks, and 29 XCTest cases (2026-07-29).

5.4 [~] Activity coordinator now keeps one transient owner during priority
handoff: a higher-priority activity drops the active lower-priority surface,
while the newest lower-priority activity suppressed during a blocker replays
after dismissal. The handoff suppresses queue draining so queued work cannot
flash between the old and replacement surfaces. XCTest
`testActivityCoordinatorReplaysSuppressedWorkAfterPriorityHandoff`,
`testHigherPriorityActivityPreemptsMedia`, and
`testIslandSceneResolverKeepsUserAndCriticalActivityPriority` passed. Reviewed
native-2× live media capture `5.4-activity/20260729-032014-media-sneak.png`
shows the registered shortcut reaching MacIsland's media activity. Full
`Scripts/validate-xcode.sh` passed Debug/Release, entitlement/branding checks,
and 30 XCTest cases (2026-07-29). Remaining: a visual capture of a real
two-producer handoff/replay; the host has no user-visible download producer and
a battery activity requires a physical power-state change.

5.5 [~] Shelf has persistence, Quick Look/share, clear/delete, loading/error,
retention, and keyboard selection. Quick Look now retains ordinary local file
URLs when no security scope is required, while releasing only scopes that were
actually opened; XCTest `testQuickLookKeepsRegularFileURLsWithoutSecurityScope`
and keyboard-selection coverage passed. Full `Scripts/validate-xcode.sh` passed
Debug/Release, entitlement/branding checks, and 31 XCTest cases (2026-07-29).
Remaining visual proof: Shelf drag, Quick Look, and share. On this host the
temporary Debug app exposed one AX window, but the supplied UI control could not
open its nonactivating panel or deliver either Finder drag of the selected
`README.md`; the panel remained `[456, 0]` at `600 x 192` and
`~/Library/Application Support/MacIsland/Shelf/items.json` remained empty.
Therefore no unverified Shelf/Quick Look/share screenshot is recorded; repeat
the three interactions on a host whose UI-control events reach the panel.

5.6 [~] Add opt-in system states beyond timer: Focus/connectivity and safe
lock-screen behavior. Do not acquire broad keyboard access for this.

Implemented 2026-07-29: Settings now offers an opt-in private Focus indicator
(with an explicit public-API limitation disclosure) and public reachability-only
connectivity monitoring. Both are arbitrated through `BoringViewCoordinator`,
render below the physical camera housing, carry VoiceOver labels, and never
request HUD-replacement Accessibility or broad keyboard access. Screen-lock
handling closes interactive content, suspends monitoring, stops the camera, and
prevents pointer, drag, and shortcut re-entry until unlock; the existing safe
hardware bridge remains opt-in.

Evidence: `Scripts/validate-xcode.sh` passed Debug/Release builds, signing and
branding checks, and 33 XCTest cases on 2026-07-29. Focus state and connectivity
settings plus the notch-safe Focus card were launched, controlled through AX,
captured, and visually inspected in
`Audit/2026-07-29-retina-2x/5.6-system-states/20260729-034744-focus-card.png`
and `20260729-034809-connectivity-enabled.png`.

Remaining visual proof: a real connectivity route transition and lock/unlock
capture. They were not forced on the active user session because doing so would
disconnect the host or lock it. Perform both on a dedicated interactive host,
then recapture before marking this item complete.

### 6. P2 — polish and quality gates

6.1 [x] Settings now has the five requested sidebar groups: Appearance,
Behavior, Gestures, Modules, and Advanced. Existing controls were preserved:
display and notch configuration moved to Behavior; pointer, trackpad, and local
shortcut recorders moved to Gestures; feature pages remain grouped under
Modules. Trackpad controls now appear only when hover-open is off, with a clear
explanation otherwise. The sidebar is native keyboard-selectable; a live
arrow-down check moved Gestures to Media. VoiceOver labels/hints now cover the
settings sidebar, HUD replacement switch, accent choices, custom-visualizer
selection/actions, and build-number action; inaccessible tap-only visualizer
rows were replaced with native buttons.

Evidence (2026-07-29): focused XCTest
`testSettingsNavigationUsesTheFiveAuditedGroups` passed; full
`Scripts/validate-xcode.sh` passed Debug/Release, signing/branding checks, and
34 XCTest cases. The rebuilt app was launched and inspected through Assistive
Access. Reviewed native-2x captures:
`Audit/2026-07-29-retina-2x/6.1-settings/20260729-040100-final-appearance.png`
and
`Audit/2026-07-29-retina-2x/6.1-settings/20260729-040300-final-gestures-policy.png`.

6.2 [~] Profile idle, hover/open/close, media, camera, drag/drop, and settings on
target hardware. Record CPU/memory/frame budgets and measured fixes.

Evidence (2026-07-29): target host MacBook Pro `Mac17,2` (Apple M5, 24 GB,
macOS 27.0) with its native 3024x1964 120 Hz Retina display. The 8.33 ms frame
budget and 33 ms hitch threshold were recorded by
`Scripts/profile-ui-performance.sh`. Five-second Instruments captures found
zero >33 ms hitches in idle (0.0% CPU / 23 MB RSS), hover (0.0% / 23 MB), open
(0.1% max / 29 MB), close (0.0% / 29 MB), Settings (0.0% / 62 MB), and live
camera mirror (2.6% max / 145 MB peak). `camera-live-state.png` visibly shows
the live preview and macOS green camera indicator. The media empty state was
0.1% max / 76 MB peak. Raw CPU samples, trace bundles, hitch and compositor
exports, host metadata, and inspected state captures are in
`Audit/2026-07-29-retina-2x/6.2-performance/README.md`. The profiling harness
now handles the required Instruments time unit, trace finalization, and peak
RSS capture; no product rendering path exceeded the budget, so no speculative
rendering fix was added.

Validation (2026-07-29): `zsh -n Scripts/profile-ui-performance.sh` and
`Scripts/validate-xcode.sh` passed (Debug/Release builds, signing/branding
checks, and 34 XCTest cases).

Remaining proof: profile an active supported media session (Spotify was
installed but idle; audio was not started for the audit) and a real Finder
drag/drop route (blocked by an unrelated macOS app-control permission sheet).

6.3 [x] Expand failure-path tests for denied calendar/camera/location, unavailable
media/XPC, display removal, sleep/wake, timer completion/recovery, clipboard
privacy filters, and activity-priority behavior.

Evidence (2026-07-29): `CalendarAccessPolicy`, `CameraPreviewPolicy`, and
`AppLifecyclePolicy` now expose the production denial and lifecycle decisions
used by CalendarManager, BoringViewModel, and AppDelegate. An injected
`XPCHelperClient` service name permits a nonexistent helper to prove the
existing fail-closed path. XCTest covers denied/restricted calendar and camera
access, denied/empty manual location responses, failing media/camera protocols,
an unavailable XPC helper, display removal, lock/sleep/wake policies, countdown
completion and persisted pause/recovery, clipboard privacy filters, and
preempt/replay activity priority. Focused five-test `xcodebuild test` passed;
`Scripts/validate-xcode.sh` passed Debug and Release builds, signing and
entitlement checks, and 38 XCTest cases with 0 failures.

### 7. Final visual and release acceptance

7.1 [~] Physical integration: closed, hover, compact, expanded, and dismiss states
fit real notches and notchless displays with no camera overlap, seams, floating
edges, or menu-bar mismatch.

Geometry restoration 2026-07-29: compared the pinned Boring Notch revision
`8dd02e7555cbe48899524c61d24e50703e68ff68` with the current AppKit/SwiftUI
window path. Restored its fixed 640 × 190 open envelope plus 20-point shadow
allowance, and centralized the centered, top-edge panel frame in
`IslandPanelGeometry`. `AppDelegate` now updates and positions the exact view
model associated with each window, rather than independently calculating a
metric frame that could diverge from the hosted root. XCTest
`testPanelGeometryKeepsTheBaselineEnvelopeTopCenteredAcrossPageChanges` proves
the 640 × 210 frame is top-centered and safely constrained on narrow displays.
`Scripts/validate-xcode.sh` passed Debug/Release, signing/branding checks, and
42 XCTest cases. Reviewed native-2× captures
`geometry-baseline-restore/home.png` and `geometry-baseline-restore/closed.png`
show the same AX frame `[436, 0] 640 × 210` in open and closed states.

Observed defect 2026-07-29 (user-provided native-display crop): while a closed
media activity is visible, the rendered black island spans the menu bar and
obscures nearby menu titles; album artwork and the visualizer appear inside the
camera-housing span rather than in side wings. The framebuffer crop does not
show the physical bezel or notch outline, so hardware overlap is not yet
measured; the visible menu-bar collision is sufficient to keep 7.1 open. Fix
the closed live-activity composition and recapture it with display metadata.

Consolidated visual defects 2026-07-29 (user-provided open Home and Shelf
framebuffer crops):

- The open Home surface ends as a sharp, full-width horizontal black edge at
  the bottom, reading as a clipped window rather than a rounded island.
- The Calendar card is cut off at that edge; its lower content and corners are
  not visible.
- “Choose a city in Settings” floats in unbounded empty space above Home
  modules instead of living in a bounded weather module.
- Media and Calendar have mismatched effective heights and bottom alignment,
  with excessive unused black canvas around and beneath them.
- Assuming the two crops are equivalent native-display captures, page selection
  changes shell geometry: Shelf is compact and centered, while Home is wider
  and shifted and its header icons move left. Page selection must not move or
  resize the panel shell.
- Shelf retains a complete rounded outer silhouette and consistent inset; Home
  loses the lower silhouette. Shelf cards fit within it, while Home content is
  pushed down by the weather warning and clips.
- Shelf has a deliberate two-column composition; Home modules do not share a
  stable height or bottom alignment.

Scope of the screenshot evidence: the crops do not represent the physical
bezel, physical notch outline, or UI outside the crop. Treat their dimensions
as Retina framebuffer pixels. The current evidence establishes an internal
native-panel surface/layout failure, not that the MacBook has no notch or that
the visible app has proven physical-hardware overlap.

Home/Shelf shell defect fixed 2026-07-29: `IslandSurface` now owns an explicit
open size, so page intrinsic content can no longer resize the visible shell.
Its horizontal content inset includes both the 19-point silhouette shoulder and
the shared 12-point visible-edge clearance. Home and Shelf therefore share one
centered shell/header rect, while Home receives the exact inner page size rather
than calculating from the panel's invisible rectangular bounds. The redundant
Home-only gutters were removed, weather uses a bounded 26-point module, and
media/Calendar receive the same explicit row height. Calendar clips to its own
rounded shape as a final overflow guard.

The closed media surface is also constrained to its deterministic
artwork/physical-bridge/visualizer width. The closed shape shoulders are
reserved outside that content so the full 20-point wings remain visible and
interactive instead of being clipped down to approximately 6 points.

Focused geometry coverage proves the standard 640 × 190 shell yields one
578 × 146 silhouette-safe page rect, including the weather-reserved row height,
and that the closed 208-point hardware bridge plus two 20-point media wings is
248 points before its shape shoulders. The target 15-inch MacBook Air brief is
covered as a 1440 × 932-point display with a 1440 × 900-point uninterrupted
safe canvas and centered 176 × 32-point camera exclusion (180-point rendered
bridge including MacIsland's 4-point overhang).

Final `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
Scripts/validate-xcode.sh` passed Debug/Release, signing/entitlement checks,
and all 43 XCTest cases with 0 failures. Fresh local 3024 × 1964 native-2× evidence
with adjacent metadata was inspected:
`home-shell-final/20260729-121547-home.png` shows a complete rounded Home
silhouette, a full 12-point visible side inset, bounded weather, fully visible
Calendar, and aligned card bottoms; `home-shell-final/20260729-122004-media.png`
shows the closed media surface no longer spanning the menu bar. The local host
is a Mac17,2 MacBook Pro, so the supplied 2880 × 1864 MacBook Air target is
proved deterministically rather than misrepresented as local hardware evidence.

Reference-quality visual pass 2026-07-29: Home now uses one semantic smoked-glass
module layer over the hardware-black shell, 18-point continuous module corners,
0.75-point quiet hairlines, and a restrained artwork-derived lower-surface glow.
The glow is disabled by the high-contrast palette. Weather is a compact bounded
capsule rather than a full-width utility bar, and header actions share the same
glass/hairline treatment. Shell size, camera exclusion, module budgeting, and
interaction behavior are unchanged.

Fresh native-2× captures with adjacent display/software metadata were inspected
in `Audit/2026-07-29-retina-2x/reference-visual-pass/`:
`20260729-123613-home.png` proves the media-only treatment, while
`20260729-123734-home.png` proves the denser weather + media + Calendar
composition remains aligned and fully contained. Calendar and Weather were
temporarily enabled only for the second audit and restored to their prior
unset/default-off values afterward. The rejected pre-click compact capture was
removed from the approved audit directory. Final
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
Scripts/validate-xcode.sh` passed Debug/Release, signing and entitlement checks,
and all 43 XCTest cases with 0 failures.

Implemented 2026-07-29: the approved audit tools now name final-review states
`expanded`, `compact`, and `dismissed`; the deterministic preparer accepts
`expanded` and `dismissed` aliases while preserving its explicit, coordinate
based state preparation. Existing deterministic coverage verifies notched,
notchless, and narrow geometry plus the physical camera exclusion and hover
edges (`testNotchMetricsCoverNotchedNotchlessAndNarrowDisplays` and
`testClosedBridgeAndHoverTargetStayOutsideThePhysicalCameraGeometry`). Retained
reviewed native-2x evidence covers closed/hover/Home (`1.9` captures), compact
timer (`5.1-timer/20260729-025645-timer-running.png`), and a settled close
(`4.5-motion-resolved/20260729-025500-closed.png`).

Validation: `zsh -n Scripts/prepare-ui-audit-state.sh Scripts/visual-audit.sh`
and `Scripts/validate-xcode.sh` passed (Debug/Release, signing and entitlement
checks, 38 XCTest cases with 0 failures).

Remaining visual proof: `Scripts/visual-audit.sh ... compact` reached its
interactive confirmation step but no valid screenshot could be made because an
unrelated system sheet, “Visual Studio Code wants access to control Spotify,”
covered the desktop. Dismiss or resolve that sheet without changing MacIsland,
then capture and inspect closed, hover, expanded, compact, and dismissed states
on this notched 2x display. Attach a notchless external display (and 1x display
if available) and repeat the same matrix before this item can be marked `[x]`.

7.2 [~] Motion: one owner per transition; state changes are short, continuous,
interruptible, and Reduce Motion-safe with no stutter or competing animation.

Implemented 2026-07-29: `IslandMotionPhase` centralizes the state,
interaction, content, and onboarding response budgets. Normal island motion is
bounded at 0.65 seconds or less; Reduce Motion settles each phase in 0.01
seconds. The onboarding snake now uses the 0.65-second policy budget rather
than a separate four-second transition. All remaining default `withAnimation`
calls in production now explicitly use `IslandMotion`, including battery,
calendar, music-idle, controls, and Settings changes; existing task cancellation
continues to interrupt delayed hover, activity, media, and onboarding work.

Evidence: focused XCTest `testReduceMotionPolicyStopsNonessentialVisualWork`,
`testIdleFaceMotionStopsWhenHiddenOrReduceMotionIsEnabled`, and
`testOpenAndCloseStateMachine` passed. The policy test covers every phase's
normal/reduced-motion budget and spectrum cancellation. The raw default-
animation search returned no unowned calls. `Scripts/validate-xcode.sh` passed
Debug/Release, signing and
entitlement checks, and 38 XCTest cases with 0 failures.

Remaining visual proof: capture a real interrupted hover/open/close transition
and the same transition with Reduce Motion enabled. Current host capture is
blocked by the protected “Visual Studio Code wants access to control Spotify”
consent sheet; standard AX lookup returned `-1728` and synthetic click input
cannot activate that macOS privacy surface. Resolve the sheet normally, enable
Reduce Motion in System Settings, and use `Scripts/visual-audit.sh` to capture
and inspect both endpoints before marking this item `[x]`.

7.3 [~] Feature consistency: media, weather, calendar, camera, timer, Shelf,
snippets, battery, and HUDs use one token system, spacing rhythm, typography,
controls, focus treatment, and empty/loading/error behavior.

Implemented 2026-07-29: `IslandStyle` now owns compact-control spacing,
padding, and radius in addition to module chrome. Media, Calendar, and snippets
consume the shared module/compact measurements rather than duplicating literals.
Battery, inline HUD, and open HUD text now use `IslandTypography` roles; the
existing timer, Shelf, weather/camera Home modules, and system-state cards
already consume the same typography and semantic `IslandPalette` colors. Shelf
retains its keyboard actions, focus-colored drop border, empty/loading/error
states, while snippets, Calendar, weather, timer, and camera retain their
feature-specific empty, unavailable, and permission-safe messaging.

Evidence: `testFeatureSurfacesShareTheModuleAndCompactControlTokenScale` and
`testIslandPaletteElevatesContrastForThemeAndSystemPreference` passed. Full
`Scripts/validate-xcode.sh` passed Debug/Release, signing and entitlement
checks, and 39 XCTest cases with 0 failures.

Remaining visual proof: inspect each named feature's normal, empty, loading,
error, selected, and keyboard-focus state in one live native-2x session. The
protected “Visual Studio Code wants access to control Spotify” consent sheet
still blocks an unobstructed MacIsland capture and cannot be activated through
synthetic input. Resolve it normally, then capture and inspect the states before
marking this item `[x]`.

7.4 [~] Native interaction: hover, click, drag/drop, keyboard navigation, Quick
Look, sharing, permissions, notification, sleep/wake, and display moves preserve
user context.

Implemented 2026-07-29: Quick Share now transfers its active interaction lease
directly from the native file picker to its sharing delegate, so the
nonactivating island cannot close between file selection and the share picker or
service. An unanchored system share picker fails safely, releasing any
security-scoped access and temporary files rather than leaving the island held
open. Existing production paths retain context for hover/click/gesture,
Shelf drop targets and keyboard selection, Quick Look scope lifetime,
activation-time camera/calendar/notification permission states, lock/sleep/wake
camera policy, and selected-display panel/drag-detector repositioning.

Evidence: XCTest
`testSharingInteractionPolicyKeepsIslandContextAcrossNativeHandoffs`,
`testShelfSelectionKeyboardNavigationClampsAtEnds`,
`testQuickLookKeepsRegularFileURLsWithoutSecurityScope`,
`testDeniedCalendarAndCameraPoliciesKeepProtectedContentUnavailable`, and
`testDisplayRemovalAndSleepWakePoliciesFailSafe` cover the deterministic
handoff, keyboard, Quick Look, permission, and lifecycle decisions. Full
`Scripts/validate-xcode.sh` passed Debug/Release builds, signing/branding
checks, and 40 XCTest cases with 0 failures (2026-07-29). A focused direct
`xcodebuild test` compiled the change but could not launch its test host because
LaunchServices returned `IDELaunchErrorDomain Code 20`; the project validation
runner then completed successfully.

Remaining live proof: exercise hover/click/close, real Finder drop, Shelf
keyboard selection plus Quick Look, file-picker-to-share handoff, camera and
notification permission flows, display move/add/remove, and sleep/wake with
native captures. The required live capture was attempted with `screencapture`
and visually inspected, but the protected “Visual Studio Code wants access to
control Spotify” consent sheet covered the desktop; it cannot be activated by
Assistive Access/synthetic input. Resolve that sheet normally, then run the
interaction matrix without changing MacIsland before marking this item `[x]`.

7.5 [~] Proof: approved MacIsland captures are compared against official
Alcove/Perch references on notched and notchless hardware; measured defects are
fixed before sign-off.

Reviewed 2026-07-29: official Alcove product presentation at
`https://tryalcove.com/` and official Perch App Store listing/screenshots at
`https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12`
were compared against the approved native-2× MacIsland closed, Home, Shelf, and
timer baseline set. The comparison is behavior/quality-only: MacIsland keeps
its own hardware-black silhouette, SF-symbol/system-typography treatment,
calendar/media composition, copy, and assets. No reference artwork, layout, or
asset was retained in the repository. The reviewed MacIsland states have no
observed physical-camera overlap, panel-edge seam, or module overflow; those
measurable notched-display defects are already covered by 1.9 and 4.4, so no
speculative visual rewrite was made.

Evidence: `Scripts/verify-ui-baselines.sh
Audit/Baselines/native-2x/manifest.plist` verified immutable 3024 × 1964
closed, Home, Shelf, and timer captures with SHA-256. `Scripts/validate-xcode.sh`
passed Debug/Release builds, signing/branding checks, and 40 XCTest cases with
0 failures. A live screen capture and AX window check were attempted, then
visually inspected; the protected “Visual Studio Code wants access to control
Spotify” consent sheet covered the desktop, so it is not accepted as MacIsland
comparison proof.

Remaining: resolve that unrelated consent sheet normally, capture the same
approved states beside the official reference review on this notched native-2×
display, then attach a notchless external display and repeat. Current host has
only one built-in notched 2× display (`safeAreaInsets.top == 32`), so required
notchless comparison and any resulting measured fixes cannot yet be proven.

7.6 [~] No P0/P1 item remains open; Developer ID/notarized release passes strict
verification and launch smoke before delivery.

Release gate reconfirmed 2026-07-29. `Scripts/validate-xcode.sh` passed Debug
and Release builds, signing/branding checks, and 40 XCTest cases with 0
failures. A fresh Release bundle at
`/tmp/macisland-task76-release/Build/Products/Release/MacIsland.app` is a valid
strictly verified nested ad-hoc bundle (`codesign --verify --deep --strict
--verbose=4` passed), but `Scripts/verify-distribution.sh` correctly stopped at
`Distribution gate failed: app is not signed with a Developer ID Application
certificate.` Its signature reports `Signature=adhoc` and `TeamIdentifier=not
set`.

External release credentials are absent: `security find-identity -v -p
codesigning` returned `0 valid identities found`; the app and helper build
settings retain an empty `DEVELOPMENT_TEAM`. Twenty prerequisite numbered
parity/release items remain `[~]` (1.7, 1.8, 2.5, 2.6, 3.5, 4.1, 4.2, 4.4–4.6,
5.1, 5.2, 5.4–5.6, and 7.1–7.5), so the no-open-P0/P1 acceptance condition is
not yet evidenced.

Remaining: close and evidence the prerequisite items; install a valid Developer
ID Application certificate and private key, archive with its configured team,
notarize and staple that exact app, rerun `Scripts/verify-distribution.sh`, then
perform launch smoke and create/share the notarized DMG. No Developer ID or
notarized app was launched, so no distribution launch-smoke claim is made.

### 8. Final audit, screenshot testing, and sign-off

8.1 [~] Run an independent code audit after all numbered fixes close: architecture,
dead paths, concurrency/lifecycle, privacy boundaries, accessibility, dependencies,
and release configuration. Record findings and resolve every P0/P1 finding before
sign-off.

Independent `ln-620` audit completed 2026-07-29 with all mandated worker lanes
(`ln-621` through `ln-629`), Apple/Swift research, and consolidated evidence in
`.hex-skills/runtime-artifacts/runs/20260729-task-8-1/audit-report/ln-620--final-report.md`.
Two confirmed P1 file-drop defects were fixed: MacIsland no longer deletes
provider-owned file-promise URLs, and every provider-suggested temporary filename
is reduced to a sanitized leaf then containment-checked against its generated
directory. XCTest `testTemporaryFileNamesCannotEscapeTheirGeneratedDirectory`
proves traversal and separator input cannot escape. `Scripts/validate-xcode.sh`
passed Debug/Release, signing/branding checks, and 41 XCTest cases with 0
failures.

Remaining P0/P1 findings prevent sign-off: Developer ID/notarization and release
CI are unavailable (2.5/2.6); image/PDF/zip work can block MainActor; and three
large multi-responsibility hotspots need staged, behavior-preserving extraction.
The audit also records medium/low entitlement, XPC hardening, dependency,
dead-code, diagnostics, persistence, and lifecycle follow-ups. Prior numbered
parity/release items remain `[~]`, so the prerequisite “after all numbered fixes
close” and no-open-P0/P1 acceptance conditions are not met.

8.2 [~] Run full automated validation: Debug build, Release build, XCTest, strict
bundle verification, distribution verification, and DMG package verification.

Automated validation rerun 2026-07-29: `Scripts/validate-xcode.sh` passed Debug
and Release builds, entitlement/branding checks, and 41 XCTest cases with 0
failures (`/tmp/macisland-derived-test/Logs/Test/Test-MacIsland-2026.07.29_05-09-57--0500.xcresult`).
A fresh locally signed Release build at
`/tmp/macisland-task82-release/Build/Products/Release/MacIsland.app` passed
`codesign --verify --deep --strict --verbose=4`. `Scripts/package-release.sh`
created `/tmp/macisland-task82/MacIsland.zip`, and `unzip -t` passed. `Scripts/create-dmg.sh`
created `/tmp/macisland-task82/MacIsland.dmg`; read-only mount inspection found
`MacIsland.app`, `Applications`, `LICENSE`, and `THIRD_PARTY_LICENSES`, and the
mounted app passed strict nested-code verification.

Distribution verification was executed on that same fresh app and correctly
stopped at `Distribution gate failed: app is not signed with a Developer ID
Application certificate.` The artifact reports `Signature=adhoc` and
`TeamIdentifier=not set`; `security find-identity -v -p codesigning` returns
`0 valid identities found`. Gatekeeper assessment and stapler validation cannot
run without the Developer ID/notarized artifact.

Remaining: install valid Developer ID Application certificate/private key and
notarization authorization, archive/sign/notarize/staple, then rerun
`Scripts/verify-distribution.sh` and package/verify the resulting notarized
DMG. Local ZIP/DMG structure proof is not release-distribution proof.

8.3 [ ] Run approved-host screenshot matrix through `Scripts/visual-audit.sh`:
closed, hover, expanded Home, Shelf, media, timer, battery/HUD, calendar, camera,
drag/drop, empty/loading/error, Reduce Motion, Increase Contrast, and every theme.
Capture 1x/2x notched and notchless displays.

8.4 [~] Live interaction reattempt completed on 2026-07-29 with the existing
single Debug instance only (`PID 38581`,
`/private/tmp/macisland-derived-debug/Build/Products/Debug/MacIsland.app`).
`Scripts/visual-audit.sh` retained native-2x hover and closed captures plus
adjacent display/software metadata in
`Audit/2026-07-29-retina-2x/8.4-interaction/`. Both PNGs were inspected:
moving the pointer to the island at `(756,15)` visibly opened Home
(`20260729-051451-hover.png`), and moving it away to `(16,966)` visibly
returned it to the closed bridge (`20260729-051507-closed.png`). No duplicate
app process was created.

The rest of the matrix is not evidenced. An unrelated protected macOS consent
sheet, “Visual Studio Code wants access to control Spotify,” stayed frontmost
in both captures. A direct `cliclick 'c:756,15'` could not establish click
delivery, and sending Escape, shortcuts, keyboard-focus, drag/drop, Quick Look,
sharing, permission, or notification input would target that protected sheet
rather than MacIsland, so none is claimed. `system_profiler SPDisplaysDataType`
reports only the built-in 3024 x 1964 Retina display; move/add/remove cannot be
tested without another display. Full-screen, Spaces, sleep/wake, and lock/unlock
remain unproven on this active session. The latest unchanged-code validation is
the passing 8.2 `Scripts/validate-xcode.sh` gate (41 XCTest cases).

At that time, resolving the Visual Studio Code-to-Spotify consent sheet was
required before current-display interaction testing could continue; the rerun
below supersedes that host blocker. A second display and a dedicated interactive
session still remain necessary for their respective matrix rows.

Rerun after the user allowed the Visual Studio Code-to-Spotify Automation
request (2026-07-29): the protected sheet was no longer present. Fresh,
inspected captures with adjacent metadata are retained in
`Audit/2026-07-29-retina-2x/8.4-interaction-rerun/`: closed
`20260729-095907-closed.png` and direct-click Home
`20260729-100303-home.png`. The audit preparer's former hover coordinate was
outside the default `NotchMetrics.hoverHitFrame`; it now targets the island
center and `zsh -n Scripts/prepare-ui-audit-state.sh Scripts/visual-audit.sh`
passes. User-confirmed manual retest (2026-07-29): normal pointer hover expands
the island, and dragging the real Finder `README.md` to the island opens and
persists Shelf. Therefore the earlier failed hover/drag screenshots are invalid
synthetic-input evidence, not product failures.

Remaining: capture those two working flows with an eased, Accessibility-driven
pointer/drag harness, then capture Shelf, Quick Look, sharing, keyboard,
permission, notification, display, and lifecycle flows. A second display and a
dedicated lock/sleep session are still required for their respective matrix rows.
The replacement preparer now derives logical target coordinates from the live
MacIsland Accessibility window and uses eased `cliclick` movement rather than
Retina screenshot coordinates. `zsh -n` passed and the inspected native-2×
capture `interaction-polish/20260729-103100-eased-ax-home.png` confirms it can
open Home through the production pointer path. Finder-source coordinate
resolution and the corresponding smooth drag capture remain.

8.5 [~] Official-reference review rerun 2026-07-29 against the Alcove product
page and Perch App Store screenshots/listing. The review is quality/behavior
only: Alcove's public state establishes a quiet, integrated locked/idle island;
Perch establishes immediate Home access to media, weather, calendar, timer,
snippets, and a temporary file tray. No reference artwork, copy, layout, or
asset was retained in the repository.

Reviewed approved native-2x MacIsland states: closed
(`20260729-015915-closed.png`), Home (`20260729-015918-home.png`), completed
timer (`20260729-014744-timer.png`), and snippets
(`5.2-snippets/20260729-030750-snippets-captured.png`). The closed bridge is
silent and camera-safe; Home keeps the media primary and Calendar secondary
below the physical housing; timer completion remains a compact, actionable
surface; and snippets presents search plus copy/delete without borrowing
Perch's visual treatment. No measured physical-camera overlap, clipping,
overflow, contrast, or control-hierarchy defect was found in those states, so
no product visual change was warranted. A fresh, inspected native-2x Home
capture with adjacent metadata is retained in
`Audit/2026-07-29-retina-2x/8.5-reference-comparison/20260729-051823-home.png`;
the unrelated Visual Studio Code-to-Spotify consent sheet remains visible but
does not cover the MacIsland surface.

Exact evidence defect: the baseline manifest's required Shelf image
`20260729-011452-shelf.png`, and later
`5.5-shelf/20260729-032451-shelf-open.png`, visibly show System Settings with
no MacIsland Shelf. They cannot support a Shelf comparison or sign-off. This
state was not replaced on the post-consent rerun: the prior automated Finder
drag evidence is invalid, while the user manually confirmed that the same real
`README.md` drag opens and persists Shelf (2026-07-29).
`Scripts/verify-ui-baselines.sh
Audit/Baselines/native-2x/manifest.plist` still passes checksum/dimension
validation, which proves file integrity—not that the claimed Shelf state is
visible.

Remaining: capture and inspect the user-confirmed real Shelf state with the
replacement pointer harness, then repeat its reference comparison. Attach a
notchless external display and repeat the approved-state comparison there before
marking this item `[x]`.

8.6 [~] Final release review rerun 2026-07-29. `Scripts/validate-xcode.sh`
passed Debug and Release builds, entitlement/branding checks, and 41 XCTest
tests with 0 failures (`/tmp/macisland-derived-test/Logs/Test/Test-MacIsland-2026.07.29_05-21-05--0500.xcresult`). A fresh Release app built at
`/tmp/macisland-task86-release/Build/Products/Release/MacIsland.app` passed
`codesign --verify --deep --strict --verbose=4`. It is only ad-hoc signed,
however (`Signature=adhoc`, `TeamIdentifier=not set`); `security find-identity
-v -p codesigning` reports `0 valid identities found`. Consequently
`Scripts/verify-distribution.sh /tmp/macisland-task86-release/Build/Products/Release/MacIsland.app`
exits 65: `Distribution gate failed: app is not signed with a Developer ID
Application certificate.` Gatekeeper and stapler verification therefore cannot
run. The independent 8.1 audit also still records the P0 release blocker and
P1 delivery, concurrency, and maintainability findings; the required visual
matrix and interaction/reference evidence remain incomplete under 8.3–8.5.
No release-ready claim, notarized app, or DMG was created or shared.
Remaining: remediate the recorded P1 findings and incomplete evidence, then
install a valid Developer ID Application certificate/private key and
notarization credentials, archive/notarize/staple the exact app, pass the
distribution gate and launch smoke, then create and verify the DMG.
