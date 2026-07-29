# MacIsland parity and native-experience closure ledger

Status: active audit — 2026-07-29

## Benchmark boundary

Alcove and Perch are behavior and quality references only. MacIsland must not
copy their artwork, copy, branded layout, or assets. It must exceed them with a
quieter, more reliable, privacy-respecting native macOS experience.

## Non-negotiable visual quality bar

Every shipped feature must feel like one coherent, native Mac app—not a widget
placed over the menu bar. Alcove and Perch set the minimum bar for polish;
MacIsland must meet or exceed it with its own visual identity.

- [ ] **Physical integration:** closed, hover, compact, expanded, and dismiss
  states fit real notches and notchless displays without camera overlap, seams,
  floating edges, or menu-bar mismatch.
- [ ] **Motion:** one owner per transition; state changes are short, continuous,
  interruptible, and Reduce Motion-safe. No stutter, bounce, delayed collapse,
  or competing animations.
- [ ] **Feature consistency:** media, weather, calendar, camera, timer, Shelf,
  snippets, battery, and HUDs use one token system, spacing rhythm, typography,
  control language, focus treatment, and empty/loading/error behavior.
- [ ] **Native interaction:** hover, click, drag/drop, keyboard navigation,
  Quick Look, sharing, permissions, notification, sleep/wake, and display moves
  feel immediate and preserve user context.
- [ ] **Proof:** each feature/state is compared against approved 1x/2x captures
  from official Alcove/Perch references and MacIsland captures on notched and
  notchless hardware. Fix measured defects before calling visual work complete.

No feature is “done” because it compiles. It is done only after code validation,
live interaction validation, and visual acceptance against this bar.

## Evidence reviewed

- [Perch App Store listing](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12): Home media/weather/camera/calendar,
  countdown + stopwatch, snippets/recent copies, temporary File Tray, and
  notchless-Mac adaptation.
- [Alcove profile](https://appstacks.club/alcove): subtle animated HUD for music,
  now playing, weather, and custom visuals; SwiftUI implementation.
- [Alcove maker interview](https://medium.com/@teslathewest/the-story-behind-alcove-macos-dynamic-island-app-dadb5d97e8b0): passive fade-in/fade-out
  behavior, lock-screen integration, and system-change-driven HUDs without
  unnecessary keyboard permissions.
- Public Alcove settings imagery also shows launch-at-login, hover expansion,
  haptics, screen-capture exclusion, display selection, tuning, system HUD,
  and live-activity sections.

## Current MacIsland result

### Present and verified

- Native SwiftUI/AppKit notch panel with physical-notch metrics and notchless
  fallback.
- Media, calendar, camera mirror, battery/HUD, Shelf drag/drop, Quick Look,
  and Quick Share.
- Countdown timer and stopwatch with pause/resume, completion attention, header
  controls, and compact live state.
- `IslandScene` now gives onboarding, system HUD, battery, timer, media, idle,
  Home, and Shelf a single explicit presentation priority.
- Shared `IslandMotion`, Reduce Motion handling, cancellable idle animation,
  stable Home module budgets, and no conditional disappearance of music controls.
- Shelf visual pass: native carbon surfaces, restrained borders, shared accent,
  accessible empty state, and no dashed upload-card treatment.
- Signed Release build passes strict nested-code verification locally. Debug and
  Release builds plus seventeen XCTest cases pass.

### Live-run limits

- Isolated app launch and display capture work. Closed idle state correctly
  renders as visually silent hardware on black desktop.
- Open/hover/click screenshots cannot be automated in current host because it
  denies Assistive Access. This blocks proof, not implementation.
- Current host has one visible display only. Notched internal, external display,
  Spaces, full-screen, sleep/wake, lock/unlock, and contrast matrix remain
  unproven.

## Required fixes — priority order

### P0 — ship blockers / visual proof

- [ ] Add an approved UI-test or Assistive-Access host. Capture closed, hover,
  expanded Home, Shelf, media, timer, battery/HUD, calendar, camera, drag/drop,
  Reduce Motion, and Increase Contrast states at 1x and 2x.
- [ ] Run same matrix on notched internal display, notchless external display,
  full-screen app, multiple Spaces, sleep/wake, and lock/unlock. Record defects
  with screenshot and display metrics.
- [ ] Tune closed wings, menu-bar blend, hit target, shadow, and physical-camera
  bridge from those captures. Hard rule: no content may paint in camera housing.
- [ ] Developer ID sign, notarize, staple, launch-smoke final app, then rebuild
  DMG. Local signing is not distribution signing.

### P1 — reference parity

- [~] Finish timer. Complete: countdown + stopwatch, compact live state,
  pause/resume, completion attention, fixed presets, and active-countdown recovery.
  Opt-in durable completion notifications schedule, reschedule, and cancel with
  timer state. Named custom presets persist and launch from the header. Remaining:
  activity interruption policy.
- [~] Build privacy-first snippets/clipboard history. Complete: explicit opt-in,
  local retention limit, dedupe, search, copy/delete, compact tab, global shortcut,
  excluded bundle IDs, and plain-text-only default. Remaining: paste-into-previous-app
  workflow (current action writes selected text to the system pasteboard).
- [x] Build opt-in weather. Complete: manual city (no location permission),
  real Open-Meteo geocoding/forecast, loading/error/last-updated states,
  15-minute local cache, Home toggle/module, and Celsius/Fahrenheit preference.
  Injected transport tests cover valid and failing Open-Meteo responses.
- [~] Replace remaining scattered live activity branches with a coordinator.
  Complete: coordinator priority/queue and tested media preemption by battery;
  current priority is `battery > system HUD > download > media`. Remaining:
  timer-completion integration, explicit user-interaction priority, and replay/drop
  policy screenshots.
- [~] Finish Shelf as a compact tray. Complete: visible count, selected-item
  Delete-key removal, overflow action, confirmed clear, loading feedback,
  Quick Look/share, retained security-scoped items, Control-arrow selection,
  per-drop error state, and a documented retention model. Remaining: screenshot proof
  for drag feedback/Quick Look/share.
- [ ] Add native notifications/system integrations missing from Alcove-class
  behavior: opt-in app notifications, Focus/connectivity state, and safe
  lock-screen behavior. Do not request broad keyboard access merely for HUDs.

### P1 — visual/native quality

- [ ] Extract `ContentView` geometry/hit-testing/clipping into one dedicated
  island-surface component; `IslandScene` already owns priority but not complete
  physical-surface ownership.
- [ ] Complete tokens: semantic primary/secondary/status text, focus ring,
  selected/pressed/disabled state, spacing scale, compact/open typography, and
  high-contrast variants. Primary, secondary, warning, surface, border, and
  elevation tokens now exist; remaining literal values and focus/state typography
  need full visual review.
- [ ] Make Home fixed-slot layouts screenshot-driven: media primary, calendar
  secondary, camera bounded; compact/open layouts must preserve controls and
  never reflow under the housing.
- [ ] Remove old/duplicate visual paths after screenshot comparison. Keep one
  transition per state change; no bouncy/decorative animation in product UI.

### P2 — reliability and accessibility

- [ ] Reorganize Settings into Appearance, Behavior, Gestures, Modules, and
  Advanced. Accent changes already avoid root rebuild; section hierarchy still
  needs refactor and keyboard/VoiceOver audit.
- [ ] Add tests for denied calendar/camera/location permission, MediaRemote/XPC
  failure, display removal, sleep/wake, timer completion/recovery, clipboard
  privacy filters, and activity-priority behavior.
- [ ] Profile target hardware: idle, hover/open/close, active media/lyrics,
  camera start/stop, drag/drop, and settings changes. Establish CPU/memory/frame
  budgets and fix measured regressions only.

## Acceptance bar

- Every visual state has approved screenshot baseline on supported displays.
- No new feature appears until permission/data/error/empty behavior is real.
- Island remains silent when idle; only stateful system information expands it.
- All controls keyboard reachable, VoiceOver labeled, and Reduce Motion/Increase
  Contrast preserve function.
- Release app is Developer ID signed, notarized, stapled, strict-verified, and
  launch-smoked before DMG delivery.
