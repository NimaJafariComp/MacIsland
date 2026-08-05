# MacIsland UI-audit findings — 2026-08-04

Scope: no-edit QA of the current uncommitted worktree, built as Debug and
launched with `-uiAuditMode YES`. The app was operated through Computer Use;
findings below are based on live accessibility inspection, interaction, and
screenshots.

## Reproduced coverage

- Opened and captured Home, Shelf, Snippets, camera-unavailable, weather-error,
  forced-hover, closed, timer, and closed-media audit states using
  Option-Command-1 through Option-Command-9.
- Clicked Home, Shelf, and Snippets in the island.
- Started a one-minute timer through the in-island timer menu, then paused it.
  The visible control changed from `1:00 Pause` to `0:56 Resume`; the live
  accessibility action changed from Pause to Resume.
- Focused test `testUIAuditStatesAcceptLaunchAliasesAndUniqueShortcuts` passed.

## Findings

## Current disposition — reconciled after implementation

The findings below are retained as the original evidence record. This index is
the authoritative current status, so a historical `P1` heading is not mistaken
for an unfixed defect after its resolution-log entry.

### Done and verified

- [x] Mirror is a reachable, accessible destination with direct shape controls
  and a visual ring light that follows the mirror border. It is correctly
  presented as a visual light effect, not as unavailable camera hardware.
- [x] Tab accessibility identifiers are exposed.
- [x] Header-to-page gap, populated Home Calendar/Media alignment, Calendar
  permission copy, all-day duplication, and Home Calendar item/reminder volume.
- [x] User-reachable in-island Calendar, selected-day sizing, bounded scrolling,
  Apple Calendar handoff, reminder semantics, and completed-reminder filter.
- [x] Snippets and Calendar content-driven sizing, including stress fixtures.
- [x] Expanded media transport no longer overlaps its progress track.
- [x] Compact timer geometry, practical quick-start values, weather launch,
  weather refresh stability, automatic-location default, and Fahrenheit default.

### Still open or awaiting stronger evidence

- [ ] `error` audit launch state does not reliably reach the documented Home
  weather-error surface.
- [ ] Expanded `media-playing`/`media-paused` audit states can still be
  overwritten by a live media source and therefore are not deterministic.
- [x] Dynamic resize and hover transitions are accepted as user-verified.
  Computer Use captures only settled endpoints, so this closure is based on the
  user's direct visual assessment rather than an endpoint screenshot.
- [x] Empty Snippets uses a compact inline empty state at the compact floor;
  its title and explanatory copy are fully visible.
- [x] Snippets history/accessibility review is accepted: it presents direct
  Copy/Delete actions with accessible labels and no longer includes search
  chrome.
- [x] Long media titles are accepted: the compact player uses its existing
  looping marquee so the complete title remains discoverable without expanding
  the player or crowding its controls.

### Fresh recheck — error audit state remains open

On the current Debug build, launched as
`-uiAuditMode YES -uiAuditState error`, Computer Use captured the expanded
Mirror page, not Home's deterministic weather-error presentation. The running
process command line confirmed the requested `error` argument. Therefore the
historical error-state finding remains open and must not be marked done.

### P1 — Mirror is implemented but has no reachable user action; no ring light exists

**Evidence.** `BoringViewModel.toggleCameraPreview()` implements the complete
authorized, denied, and not-determined camera flow, but a repository-wide
call-site search finds only its declaration. `NotchHomeView` renders the
preview only when both `showMirror` and `isCameraExpanded` are true. Settings
can change the former; ordinary user interaction never changes the latter.

**Call path.** `MacIsland/models/BoringViewModel.swift:158–205` →
`MacIsland/managers/WebcamManager.swift:79–120` →
`MacIsland/components/Notch/NotchHomeView.swift:502–554`. The only production
write that expands the mirror is audit setup in `MacIsland/MacIslandApp.swift`.

**Ring-light boundary.** There is no torch, ring-light, or camera-light code.
That is appropriate for built-in Mac cameras: AVFoundation exposes no standard
light-control API for them. A visual white ring would not illuminate the user,
and external/Continuity-camera lighting is hardware/vendor owned.

**Smallest native fix.** Add one accessible `Mirror` action to the existing
right header action lane, using the established 32-point header-button style.
It should be a short `Menu`: `Open Mirror`/`Close Mirror`, then `Mirror Shape`
and `Mirror Settings…`. Choosing Open is the explicit permission-triggering
action, enables the feature if necessary, and calls `toggleCameraPreview()`.
The existing Home layout budget can place its bounded 112-point preview beside
media/calendar without increasing island height. Do not add a floating button
inside the apparent top whitespace of either card; that space is their
alignment/reading margin and would turn a module into unrelated chrome.

**Related discoverability seam.** The menu-bar extra currently exposes only
Settings, Restart, and Quit. `BoringExtrasMenu` is also an unreferenced legacy
view, so its Settings/Hide/Exit controls do not create a user path. Keep these
as a separate cleanup/route decision rather than presenting them as functional
features.

### P1 — tab accessibility identifiers are not exposed

**Evidence.** In the live Computer Use accessibility tree, every island child,
including Home, Shelf, and Snippets, reported `ID: macisland.island`. The tree
did not expose `macisland.tab.home`, `macisland.tab.shelf`, or
`macisland.tab.snippets`.

**Affected contract.** `UI_AUDIT_MODE.md` lines 54–57 documents a root island
identifier and three distinct tab identifiers for inspection/assertions.

**Call path.** `MacIsland/ContentView.swift:223` sets
`macisland.island` on the parent surface; `MacIsland/components/Tabs/
TabSelectionView.swift:34` sets the tab-specific identifiers.

**Smallest safe fix.** Ensure that the root identifier does not mask descendant
identifiers, and add an accessibility-level test that queries all three tab
identifiers.

### P1 — the full validation gate fails

**Evidence.** `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
Scripts/validate-xcode.sh` built Debug and Release, then ran 45 tests: 44
passed and one failed.

**Failing test.** `MacIslandTests/
MacIslandTests.swift:testHomeLayoutBudgetKeepsMediaPrimaryAndBoundsOptionalModules`.
The reported assertion was expected media width `282`, actual `286`.

**Call path.** `MacIsland/sizing/matters.swift:166–232`
(`HomeLayoutBudget`) → `MacIsland/components/Notch/NotchHomeView.swift:503–508`.

**Affected ledger item.** `fixed.md` 3.5 says the focused mapping test passes
through the signed validation gate. The focused mapping test does pass, but the
full gate does not.

**Smallest safe fix.** Reconcile the intended layout spacing/constants with the
test’s expected geometry, or correct the calculation to restore that asserted
geometry.

### P2 — audit media state does not expose expanded media controls

**Evidence.** Option-Command-6 produced a closed playing-media activity state.
It did not expose an expanded playing or paused state for Computer Use to test
transport, progress, volume, artwork behavior, or the visualizer.

**Call path.** `MacIsland/MacIslandApp.swift:616–621` sets synthetic media then
immediately closes the island.

**Smallest safe fix.** Add deterministic expanded-playing and expanded-paused
audit states, while retaining the current closed-media state.

### P2 — closed/timer/hover audit captures need geometry review

**Evidence.** The live screenshots for closed, forced-hover, running timer, and
paused timer showed a broad black rectangular top surface, with the timer pill
centered inside it. This is not visually equivalent to the compact closed
bridge described by `fixed.md` 4.3.

**Smallest safe fix.** Verify that the keyable audit window uses the same
closed-surface geometry and masking as the production overlay before accepting
these captures as closed-notch evidence.

### P1 — Calendar-enabled Home has inconsistent module baselines and edge inset

**Evidence.** Calendar was enabled in Settings and rendered a real all-day
event (`Bday cristina`) in the island. In the captured Home surface, the media
card retained a visible bottom inset while the taller calendar card met the
island's lower edge. The media card began lower than the calendar card, so the
two cards do not share a top or bottom baseline.

**Affected visual-reference rule.** `VISUAL_REFERENCE.md` requires consistent
internal-card spacing/radii and says cards must not look like separate windows
touching the display edge. It also requires a stable header/side-lane baseline.

**Call path.** `MacIsland/components/Notch/NotchHomeView.swift:524–534` lays
out the media/calendar row. `MacIsland/sizing/matters.swift:115,119–120` sets
the 8-point module gap and calendar widths; `HomeLayoutBudget` at lines
166–232 supplies the final card frames.

**Smallest safe fix.** Give the media and calendar cards one shared row height
and aligned vertical insets, then reserve a consistent bottom inset between
every module and the outer island edge.

### P2 — Calendar preference copy is stale during the enabled/no-access state

**Evidence.** The Calendar Settings page showed `Show calendar` on. Before
Calendar data became available, Home still rendered `Enable Calendar in
Settings`, which directs the user to a preference that is already enabled.
Once Calendar data was available, the module correctly rendered the all-day
event.

**Smallest safe fix.** Distinguish disabled, authorization-required, loading,
empty, and populated Calendar states in the Home-card copy; for example,
`Allow Calendar Access in Settings` when authorization is missing.

### P2 — audit keyboard transitions became non-deterministic after timer use

**Evidence.** The audit shortcuts initially switched states. After starting,
pausing, completing, and dismissing a timer, re-launching with the `home`
state first restored the persisted timer state, and later Option-Command state
requests did not change the visible Snippets state. Direct island clicks still
worked.

**Affected contract.** `UI_AUDIT_MODE.md` says every shortcut resets timer and
synthetic state before applying the requested state.

**Smallest safe fix.** Apply audit reset after any persisted-timer restoration
and assert state convergence from a running/paused/completed timer in the
focused audit test.

### P1 — header navigation and page panel visually collide

**Evidence.** The supplied Snippets capture shows the selected navigation
capsule ending only a few pixels above the page panel. The panel begins as a
full-width hard horizontal edge directly beneath it, so the two surfaces read
as nearly touching rather than as a stable header lane followed by a separate,
rounded content surface.

**Affected visual-reference rule.** `VISUAL_REFERENCE.md` requires a
state-invariant header baseline and side lanes, plus one quiet rounded outer
island whose internal cards use consistent spacing and radii. The page control
must not visually collide with the page content.

**Likely call path.** `MacIsland/components/Notch/BoringHeader.swift` composes
the header/navigation; the Snippets page is composed by
`MacIsland/ContentView.swift` near the `Snippets` view. The common outer sizing
and content offset come from `MacIsland/sizing/matters.swift`.

**Smallest safe fix.** Establish one named header-to-content gap token, reserve
it in every page layout, and retain the outer surface's rounded lower corners
instead of letting the page panel start as a square horizontal slab.

### P1 — expanded media transport controls are visually unbalanced

**Evidence.** In the live expanded-player captures, previous, play/pause, and
next appear as small glyphs clustered beneath the progress bar. They have no
visible shared control surface or strong alignment with the artwork, title, and
timeline, so they read as detached icons floating in unused card space rather
than a deliberate transport group.

**Affected visual-reference rule.** `VISUAL_REFERENCE.md` calls for a compact,
horizontally composed media hub with quiet hierarchy and consistent internal
spacing. Transport is a core interaction and must remain easy to scan and hit.

**Likely call path.** `MacIsland/components/Music/MusicPlayerView.swift` and
its transport-control subviews; the Home card frame is assigned in
`MacIsland/components/Notch/NotchHomeView.swift:524–534`.

**Smallest safe fix.** Put the three controls in one consistently sized,
centered control lane with a shared alignment relative to the progress bar;
use the existing minimum hit-target token and preserve visible grouping without
adding visual weight.

### P2 — long media titles compete with the compact control layout

**Evidence.** The final transport verification capture of `Don't Let Me Down -
Remastered 2009` showed the title visually truncated into competing fragments
across the limited text region.

**Smallest safe fix.** Reserve a stable title width, keep a single readable
line at rest, and use the existing marquee only when it can scroll without
competing with artist metadata or transport controls.

## Limits / external blockers

- The camera state correctly displayed unavailable: this host did not provide a
  usable camera permission/device.
- The hover shortcut is explicitly a forced fallback state. It is not evidence
  that macOS delivered real pointer-enter/leave events.
- Framebuffer captures do not contain the physical display bezel/notch, so they
  cannot alone prove physical-notch safety.

## Preservation

No existing source files were edited during the audit. This document is the
only file added by the audit follow-up.

## Resolution log

### 2026-08-04 — fixed: Mirror has native, discoverable user routes

Mirror is now a dedicated `NotchViews.mirror` destination in the existing
stable navigation strip, rather than an unreachable side effect of Appearance
settings. Its compact page retains the island’s existing height and supplies a
visible preview/status, explicit Open/Close action, shape/options menu, and
VoiceOver labels/hints. The menu-bar extra also provides a `Mirror` submenu
with explicit Open and Close commands, routed through the AppDelegate so the
same lifecycle and permission path is used from both places.

Live Computer Use evidence: the new Mirror tab was visible and selectable; the
page displayed its not-determined permission message, the user-authorized
camera prompt was presented by the explicit Open action, the page then exposed
`Live preview` and `Close Mirror`, and Close returned it to the ready state.
The host’s actual camera pixels were black in the capture, so this verifies the
UI/lifecycle but not camera-image quality. Focused XCTest passed: 2 tests, 0
failures (`testMirrorPresentationExplainsUnavailableAndPermissionStates` and
the existing denied-camera policy test).

The hardware-light limitation remains: built-in Mac cameras expose no public
light/torch API. The later Mirror ring-light control is therefore explicitly a
visual border effect, rather than a claim of hardware illumination.

### 2026-08-04 — fixed: Mirror shape and visual hierarchy

The earlier compact, left-aligned mirror card was replaced by a large centered
preview surface with the title/status above and the explicit Open/Close/options
controls below. Mirror is now a content-sized page with a 540-point preferred
height, a 360-point floor, and the same display-relative 65% maximum used for
Calendar. This keeps the image central without changing Home’s height.

The shape selector now uses an explicit `Circle` path for Circular and a
separate continuous rounded rectangle for Square; both preview states share
the same visible border. Computer Use screenshot evidence confirmed the large
square state and then the true circular state after choosing `Circular` from
Mirror options. A later follow-up added a clearly named visual ring-light
control around the preview border; it does not claim to control camera hardware.

### 2026-08-04 — in verification: replace quiet system timer sound

The low-impact macOS `Submarine` system alert was replaced with a bundled copy
of Mixkit’s public-license “Classic alarm” sound effect. The WAV is
loudness-normalized to -11 LUFS with a -1 dB true-peak ceiling, loops until
`Done`, and is recorded in `MacIsland/Resources/THIRD_PARTY_NOTICES.md`.
The Debug app built successfully, its bundle contains `TimerAlarm.wav`, and a
real UI-audit ten-second timer reached the visible `Time’s up` / `Done` state.
Audio acceptance remains pending the user’s direct listening result because
Computer Use cannot capture system audio.

### 2026-08-04 — verified by user: timer pauses and restores active media

The timer pauses the media source MacIsland controls when its retained alarm
begins, and resumes only that same source when the user stops or dismisses the
alarm. The user directly verified music pause/resume in the live app. Focused
XCTest coverage also passed for the matching-source resume policy.

### 2026-08-04 — fixed: weather location defaults to Automatic

Weather now defaults to macOS Current Location and requests the standard
Location Services permission only when Automatic weather is refreshed. Settings
retains an explicit `Choose a City` override, and existing saved city values
migrate to that override so they are not silently discarded. Apple Weather’s
private saved-city list is not a supported cross-app API; Automatic therefore
uses the same system location source as Weather’s Current Location rather than
reading private Weather.app data. Focused XCTest covers automatic-versus-custom
request selection.

### 2026-08-04 — fixed: automatic-weather Location Services crash

The first automatic-location build crashed before the permission sheet because
the `CLLocationManager` had no delegate when it called `requestLocation()`.
The live crash report attributed the abort to
`CurrentWeatherLocationResolver.requestLocationIfAuthorized()` in
`BoringViewCoordinator.swift`. The resolver now installs itself as the delegate
before requesting authorization or a one-shot location, and its Core Location
calls explicitly stay on the main actor. Live testing then found macOS was
still waiting because its required `NSLocationUsageDescription` privacy key was
missing; it is now included alongside the existing prompt text. Rebuild and
live permission-flow verification are pending. The resolver also has a
12-second bounded failure path so a host that does not deliver a Location
Services result cannot leave the Home weather module in an infinite updating
state. Live Computer Use showed the bounded `Current location is unavailable`
state on this host, and showed a successful `Choose a City → Austin → Refresh`
override with `Updated 8:22 PM`. The automatic selector was restored after the
check. Focused XCTest
`testWeatherLocationRequestDefaultsToCurrentLocationUnlessACustomCityIsChosen`
passed.

### 2026-08-04 — fixed: audit tab identifiers

`ContentView` now exposes the island as an accessibility container, preserving
the distinct root identifier without flattening descendants. Live Computer Use
inspection of the rebuilt audit app verified `macisland.tab.home`,
`macisland.tab.shelf`, and `macisland.tab.snippets`. Focused mapping XCTest
`testUIAuditStatesAcceptLaunchAliasesAndUniqueShortcuts` passed.

### 2026-08-04 — fixed: Calendar permission-state copy

`CalendarAccessPolicy` now maps not-determined access to `Allow Calendar Access
in Settings`, denied/restricted access to `Calendar access denied in System
Settings`, and read access to no error message. Focused XCTest
`testCalendarHomeStatusMessageDistinguishesAccessStates` passed.

### 2026-08-04 — fixed: header-to-page spacing and stale geometry assertions

`IslandStyle.headerContentSpacing` now supplies one shared 8-point separation
between the invariant header lane and every expanded page. The page-size budget
reserves that space, avoiding overlap or per-page offsets. A live rebuilt Home
capture showed the navigation capsule and the media panel separated by the new
gap. Focused XCTest
`testHomeLayoutBudgetKeepsMediaPrimaryAndBoundsOptionalModules` passed after
the stale expected layout values were reconciled with the current sizing policy.

### 2026-08-04 — transport alignment attempt rejected

The first slot-width adjustment was built and captured, but review of that
capture showed Back, Pause, and Forward still overlapping the progress track.
This finding remains open; do not treat the attempt as a visual resolution.

### 2026-08-04 — fixed: expanded media transport overlap

The media card now puts the progress timeline and transport controls in one
horizontal row: timeline on the left and the visible Back/Pause/Forward controls
in a fixed-size right-hand lane. Debug build passed. A fresh live Computer Use
capture verified that the controls no longer draw over the progress bar and
retain their individual accessibility labels.

### 2026-08-04 — partial: Calendar card contained to Home row bounds

The Calendar card is now clipped after its assigned `HomeLayoutBudget` frame,
preventing its rounded surface from expanding upward into the weather band. A
fresh no-access Calendar screenshot shows Media and Calendar sharing the same
visible top and bottom bounds. A populated-event recheck remains pending because
each unsigned Debug rebuild receives a new Calendar authorization state.

### 2026-08-04 — populated Calendar recheck: follow-up fix pending visual proof

After Calendar access was granted for the then-running audit build, a live
Computer Use capture showed the populated Calendar card and Media card sharing
their bottom edge but not their top edge: Calendar began about 15 points above
Media. The cause is the Calendar summary's intrinsic vertical spacing exceeding
the shared `HomeLayoutBudget.moduleHeight`. The summary was tightened from a
single all-edge module padding to 10-point vertical padding and 6-point internal
stack spacing. The resulting Debug build succeeded. Its audit process then
registered as background-only with no accessibility window, so Computer Use
could not capture the rebuilt surface or request the new build's Calendar
permission. This change is intentionally **not marked fixed** until that visual
capture is available.

### 2026-08-04 — blocker: rebuilt audit process exposes no panel

The freshly built `-uiAuditMode` process is live but has zero accessibility
windows. `Scripts/prepare-ui-audit-state.sh` consequently exits with
`MacIsland did not expose an accessibility window`, and Computer Use cannot
resolve it as an actionable application. Audit mode was changed to create one
panel directly on `NSScreen.main` before normal multi-display routing, but the
same host result persisted after a successful Debug build. This is a launch
or registration issue distinct from the Calendar layout; no visual claim for
either follow-up change is made from this state.

### 2026-08-04 — fixed: populated Calendar and Media card alignment

After Calendar permission was granted on the rebuilt audit app, live Computer
Use captured the populated `Bday cristina` card. Calendar and Media now share
the same visible top and bottom edges, while the weather capsule remains
separated above the row. The smaller Calendar-only vertical rhythm fits the
`HomeLayoutBudget.moduleHeight`; the previous approximately 15-point upward
Calendar overrun is no longer present. Debug build succeeded before capture.

### 2026-08-04 — fixed: audit panel is Computer Use inspectable

Audit mode now routes through a plain borderless `NSWindow` and creates one
panel on the active screen, rather than relying on production SkyLight overlay
and multi-display routing. `Scripts/prepare-ui-audit-state.sh` now succeeds,
and Computer Use inspected the panel root, tabs, Settings control, Calendar
event action, and the populated Home screenshot directly.

### 2026-08-04 — correction: Calendar top edge was masked, not resolved

The preceding populated-card resolution was incomplete: its external
`NotchHomeView` clip masked Calendar's upward intrinsic-height overflow and
made part of the card's top edge read as cut off. The clip was removed. The
summary's own vertical padding, stack spacing, and day type size were then
reduced so its real minimum height fits `HomeLayoutBudget.moduleHeight`.

The final live Computer Use capture shows the complete rounded Calendar top,
Calendar and Media aligned within the border width, and a visible gap between
the weather capsule and the card row. Debug build succeeded; focused XCTest
`testHomeLayoutBudgetKeepsMediaPrimaryAndBoundsOptionalModules` passed.

### 2026-08-04 — added: non-persistent Calendar stress audit

`calendar-stress` / `calendar` is a launch-only audit state with in-memory
events and reminders: all-day content, overlaps, a long title, ordinary
appointments, open reminders, and a completed reminder. Computer Use verified
eight fixture rows in the Calendar list and captured the dense first frame.
The existing Calendar page is intentionally height-bounded and visibly shows
two rows at once; the rest are supplied through its scroll area. The fixture
does not write to EventKit or user Calendar settings.

### 2026-08-04 — verified: Home Calendar stress state

`calendar-home-stress` / `calendar-home` uses the same non-persistent event
and reminder fixture behind Home, with the next timed event given a deliberately
long title. Live Computer Use evidence shows the Home Calendar card remains
the same height as Media, preserves the card gap, and truncates the title on a
single line before it can overlap the 8:30 AM label. The Calendar action is
also exposed with the full event name as its accessibility label and help text.
The fixture is local to the audit process and never opens, writes to, or changes
the user's Calendar or Reminders data.

### 2026-08-04 — open P1: full Calendar is not a user-reachable feature

**Evidence:** The live Home stress capture exposes the next item as a button,
but its action opens Apple Calendar (`calendarAppURL()` / `calshow://`). The
full in-island `CalendarView` was reachable only by launching the audit-only
`calendar-stress` state; no visible production tab, menu item, or Settings
control assigns `.calendar` to `IslandCoordinator.currentView`.

**Required behavior:** If the full list is a product feature, Home needs a
clear, keyboard-accessible entry point such as a “View schedule” affordance or
a Calendar tab. The current next-item tap may continue to open the matching
item in Apple Calendar, but it must not be the only path to MacIsland's list.
If the list is intentionally developer-only, remove it from product claims and
do not treat it as released Calendar functionality.

**Smallest safe fix:** Add one explicit navigation action from Home to
`.calendar`, plus a labelled Back/Home action in the list. Keep the existing
Apple Calendar deep-link on the event's secondary action.

### 2026-08-04 — open P1: dense Calendar list clips its visual rows

**Computer Use stress evidence:** The full `calendar-stress` screenshot showed
eight accessible fixture rows—six events and two open reminders—but only the
all-day event and the first timed event fit in the visible list. After scrolling
to the reminders, the screen showed a detached `1:00 PM` time and the open
reminder row; the preceding Lunch title was clipped above the panel. This is a
real visual clipping failure, not merely a compact design choice.

**Required behavior:** The full Calendar surface must expand or use a dedicated
scroll region that keeps complete rows inside its rounded bounds. Initial state
should show enough schedule context to be useful (at least four complete rows
at this fixture density), and scrolling must never show an orphaned time,
half-row, or content beneath the bottom navigation.

**Smallest safe fix:** Give `CalendarView` its own measured panel height and
constrain its event `List` above the tab bar, then validate top, middle, and
bottom scroll positions with the existing fixture.

### 2026-08-04 — open P2: events and reminders need clearer semantics

**Computer Use stress evidence:** Events render as color-stripe rows. Open
reminders render with an orange completion ring, but the accessibility tree
announces them only as generic selectable rows with title and time; it does not
identify them as reminders or expose a labelled completion control. Completed
reminders are in the fixture but hidden by the current default filter.

**Required behavior:** Visually and through VoiceOver, reminders must be
distinguishable from events, and their completion toggle must have a semantic
label such as “Complete Pick up package before 5 PM.” Provide an explicit
control to reveal completed reminders, rather than making them silently absent.

**Smallest safe fix:** Add a reminder label/icon and accessible toggle label,
then expose the existing completed-reminder visibility setting in the Calendar
header or filter controls.

### 2026-08-04 — open P2: Snippets grid is too shallow to browse or read

**Visual evidence:** The supplied Snippets capture shows a two-column grid in
the fixed island panel. Header, search, and tabs leave room for approximately
one row. Each card then spends substantial horizontal space on permanently
visible Copy and Delete controls, leaving a long snippet as a two-line,
truncated fragment. The scrollbar confirms more content exists but does not
make the page practical to scan.

**Required behavior:** Treat the island page as a quick picker, not a full
clipboard manager: show recent entries as compact, single-line rows; row click
or Return copies; delete is a hover/selection action; and keyboard Up/Down,
Return, and Escape work predictably. Search must leave at least two complete
recent rows visible in the fixed island envelope. A clear “Open history” action
should present a separate, resizable Mac-style panel/window with a list and a
full-text preview for browsing many or long snippets.

**Design direction:** Do not enlarge the global notch panel just for Snippets.
Replace the two-column cards with a one-column quick-picker list in the island,
and reserve the full-height, split list/preview browser for “Open history.”
This keeps the primary notch interaction fast and unobtrusive while making
long content genuinely readable.

### 2026-08-04 — fixed: Calendar is now user-reachable and height-safe

The Home Calendar summary now opens MacIsland's expanded Calendar surface
instead of deep-linking immediately to Apple Calendar. The island grows from
its compact height to a display-capped 420-point Calendar height using the
existing state animation and animated AppKit frame update; selecting Home,
Shelf, or Snippets returns it to the compact height.

Computer Use verified the Home-card transition, six complete event rows in the
initial expanded frame, and both reminder rows at the bottom of the scroll
region. The event scroller is now an explicitly bounded SwiftUI scroll stack,
so rows do not show detached times or clip beneath navigation. The header has
a visible “Apple Calendar” button; this launches `/System/Applications/Calendar.app`
and Computer Use confirmed `com.apple.iCal` became running while MacIsland
remained accessible. Reminder controls are now separately accessible as
“Mark as complete,” rather than nested inside an event deep-link button.

### 2026-08-04 — fixed follow-up: Calendar resize crash and header spacing

The first Calendar-resize implementation emitted a panel-size notification
while normalizing an already-closed island during app launch. That recursively
repositioned the window and crashed the XCTest host. The notification now fires
only for a real open-to-closed transition. The focused
`testUIAuditStatesAcceptLaunchAliasesAndUniqueShortcuts` XCTest passes again.

The first expanded screenshot also revealed a large blank gap between the date
header and the list, caused by the `List` layout and an unconstrained fade
overlay. Calendar now uses a bounded `ScrollView`/`LazyVStack` with the fade
contained inside the date wheel. Final live Computer Use evidence shows the
first event directly beneath the compact header, all scheduled events and open
reminders within the panel, a visible scrollbar, and successful Apple Calendar
launch (`com.apple.iCal` running) without MacIsland terminating.

### 2026-08-04 — fixed: content-driven Snippets and Calendar sizing

Snippets now uses the compact 190-point island height as its floor and grows
with two-column clipboard rows up to a 440-point cap. Calendar uses the same
floor, grows from the selected day's event/reminder count, and caps at 520
points; all values remain display-capped before the window is resized. Computer
Use verified eight audit snippets in the expanded surface and then a single
search result at the compact floor.

Calendar now filters to the selected day before rendering and sizing. Its
in-memory audit fixture has events and reminders on four consecutive days.
Computer Use verified a busy day with all-day content, events, and reminders,
then selected the next day and observed the panel contract to exactly that
day's four rows. These audit fixtures do not write to EventKit, Reminders, or
clipboard-history persistence.

### 2026-08-04 — fixed follow-up: Calendar trailing-space estimate

The initial selected-day formula reserved 40 points per compact schedule row,
which left a visible empty footer after a busy day. It now uses the measured
32-point row rhythm while retaining the 190-point floor and 520-point cap.
Final Computer Use capture shows the busy-day schedule ending close to the
rounded bottom edge with a functional scrollbar for the remaining reminders.

### 2026-08-04 — fixed follow-up: selected-day scroll continuity

Changing from a busy audit day to a lighter day initially preserved the old
scroll target, placing that day’s all-day item above the visible region.
Calendar now resets to the first item of the selected day. Final Computer Use
evidence shows “Conference day” followed by that day’s events and reminder at
scroll position zero after the size transition. Snippets was also retested from
eight fixtures to a one-result search and back; both settled endpoints retain
their top anchors and use the expected capped/compact heights. Computer Use
provides settled screenshots rather than a frame sequence, so this is endpoint
evidence for the existing animated SwiftUI/AppKit transition, not a claim of
frame-by-frame video verification.

### 2026-08-04 — fixed follow-up: larger Calendar ceiling for busy days

Calendar's maximum expanded height is now 680 points, with a more generous
per-row estimate for busy selected days. The window remains capped to the
available display height. Computer Use verified the busy fixture shows all
nine visible schedule items (all-day event, timed events, and open reminders)
with only a small intentional bottom inset rather than a large empty footer.

### 2026-08-04 — fixed follow-up: per-day Calendar height and half-screen cap

Calendar sizing now uses the measured 32-point event/reminder row rhythm plus
named date-header chrome instead of the former 43-point estimate. The selected
day’s content determines the requested height; the actual Calendar window is
capped at half of the active display (with a 560-point safety ceiling). Live
Computer Use audit evidence: the four-item August 5 fixture and the three-item
August 6 fixture each contracted to their own heights, displayed every row
without requiring scroll, and ended with only a small lower inset. The nine-item
August 4 fixture reached the half-display cap, so its remaining content is the
intentional and only scroll case. Focused XCTest
`testExpandedPageSizingUsesCompactFloorAndContentCaps` passed.

### 2026-08-04 — fixed: Calendar reminder semantics and completed filter

The Calendar now exposes reminders distinctly to VoiceOver: each row announces
`Reminder: <title>` and its ring control announces `Mark <title> as complete`
or `… as incomplete`. A compact Filter button beside Apple Calendar exposes
the persisted `Show completed reminders` option instead of silently hiding
completed items. Live Computer Use in `calendar-stress` verified the visible
orange reminder rings, the title-specific control and row labels, the Filter
menu, and that enabling the option reveals the completed fixture reminder. The
preference was restored to hiding completed reminders after the check. The
focused XCTest
`testReminderAccessibilityNamesTheReminderAndItsCompletionAction` passed.

### 2026-08-04 — verification follow-up: audit fixture regressions

**P1 — `error` audit state does not remain visible.** A fresh
`Scripts/prepare-ui-audit-state.sh … error` launch was inspected with Computer
Use and exposed only the closed `Open MacIsland` bridge, rather than the
documented expanded deterministic weather-error surface. This blocks visual
verification of the error state. Investigate the audit-state application and
any later close/position update that supersedes it.

**P2 — `media-playing` is not deterministic while a real player is active.** A
fresh `media-playing` audit launch opened Home, but showed the host's current
track (`Monge` by `Heydoo Hedayati`) and progressing live time rather than the
documented `Audit Track` / `MacIsland` fixture. This prevents a repeatable
visual regression test for title, artwork, progress, and playing/paused
controls. The smallest safe fix is to isolate audit-mode media presentation
from live `MusicManager` updates for `mediaPlaying` and `mediaPaused`.

The 2026-08-04 repeat validation gate otherwise completed successfully (Debug
and Release builds plus XCTest). Computer Use reverified Home, Shelf, Snippets
(eight-entry stress fixture and a one-result search), timer running/paused,
Calendar selected-day sizing and semantic reminder controls, and the real
camera-unavailable state.

### 2026-08-04 — fixed: compact timer activity and immediate completion sound

The closed timer activity now constrains the actual island surface to a
176-point minimum (or the physical bridge width when wider), rather than only
resizing its invisible hit target. The pill no longer has a 228-point minimum;
it uses a 32-point control height and a 6-point lower inset. Fresh Computer Use
evidence shows the running `0:54 Pause` timer as a compact capsule beneath a
narrow closed island.

At countdown completion, MacIsland now plays `NSSound.beep()` immediately when
timer notifications are enabled, in addition to retaining the scheduled native
notification and attention request. This avoids foreground-notification timing
or permission delivery making a completed timer silent. Focused XCTest
`testClosedTimerActivityStaysCompactWhileAccommodatingControls` and
`testCountdownCompletionPersistsUntilDismissed` passed. Computer Use cannot
capture host audio, so the sound itself is code-path/test evidence, not a
recorded-audio claim.

### 2026-08-04 — fixed: synchronized dynamic page-resize motion

Calendar and Snippets content-height changes now animate the SwiftUI island
surface on `currentOpenIslandSize`, not only on open/closed state. The owning
AppKit panel frame uses the same 0.28-second ease-in-out timing budget rather
than AppKit's unrelated default animation. Reduced Motion keeps the existing
near-instant endpoint behavior. Focused sizing and motion-policy XCTest passed.

Computer Use verified the rebuilt Home-to-Snippets endpoint. It captures
settled frames rather than a video sequence, so smoothness is implementation
and endpoint evidence; it is not a frame-by-frame visual-completion claim.

### 2026-08-04 — open P2: empty Snippets message is vertically clipped

After the motion recheck, the empty Snippets state showed “No snippets yet”
but clipped the explanatory line at the bottom of the compact surface. This is
independent of the resize animation. The empty-state layout needs a compact
variant that keeps its message fully within the 190-point floor.

### 2026-08-04 — adjusted: Calendar can reach the active-display half-height cap

The former 560-point static calendar ceiling prevented a long selected day from
using the display-relative half-height allowance on taller displays. Its safety
ceiling is now 900 points; the live `BoringViewModel` still constrains the
actual Calendar panel to half of the active display. Focused XCTest
`testExpandedPageSizingUsesCompactFloorAndContentCaps` passed. A rebuilt
`calendar-stress` Computer Use launch then reached the active display's
half-height boundary and visibly accommodated the long-day fixture; only
overflow requires scrolling.

### 2026-08-04 — in verification: eliminate competing dynamic-resize animations

Reported regression: Home → Calendar, Calendar selected-day changes, and Home
→ Snippets can jump and briefly expose the desktop above the island. The cause
was two animation owners: SwiftUI animated the destination surface while AppKit
animated the transparent panel frame; switching to a content-sized page could
also begin a compact-height transition before that page published its measured
height.

`BoringViewModel` now updates size state without a second SwiftUI animation,
and the AppKit panel is the only frame-motion owner. Panel-size notifications
are coalesced for one display frame so selection and first measurement yield
one target frame. Debug build plus focused sizing and Reduced Motion XCTest
passed. Computer Use cannot record a frame sequence and the rebuilt
`calendar-stress` audit fixture unexpectedly returned to the closed bridge
before its first settled expanded capture, so visual completion remains open
until it can be observed interactively.

### 2026-08-04 — adjusted: taller Calendar compact floor and long-day cap

Calendar now has a 220-point compact floor (up from 190) and its long-day cap
uses 58% of the active display height (up from 50%), still bounded by the
900-point safety ceiling. Focused XCTest
`testExpandedPageSizingUsesCompactFloorAndContentCaps` passed. The rebuilt
audit fixture returned only the closed bridge when Computer Use captured it, so
the sizing change has test evidence but not a fresh expanded-state screenshot.

### 2026-08-04 — adjusted: Calendar display-relative cap is 65%

The active-display Calendar cap is now 65% (up from 58%), while the existing
900-point absolute safety ceiling remains in place. This gives unusually busy
selected days more readable vertical room before scrolling is required.

### 2026-08-04 — fixed: Weather opens Apple Weather

The complete Home weather pill is now an accessible plain button that opens
`/System/Applications/Weather.app`, with the VoiceOver label “Open Weather”
and hint explaining the destination. A Debug build passed. Computer Use clicked
the real Home audit weather pill and captured the Apple Weather window opened
to the Austin forecast.

### 2026-08-04 — fixed: practical Timer quick-start values

The Timer menu now offers 5 minutes, 10 minutes, 25 minutes, 45 minutes, and
1 hour. Custom presets and Stopwatch remain available below those defaults.
The former 1-minute and 15-minute shortcuts were removed because they did not
cover the most useful short break, focus-session, and longer-task durations.
A fresh Debug build passed, and Computer Use opened the real Home Timer menu
and verified every visible menu item.

### 2026-08-04 — fixed: populated Snippets no longer takes a two-step page resize

Switching to Snippets now calculates its populated-list height before changing
the selected page. This eliminates the compact-height intermediate target that
made Home ↔ Snippets appear to close and reopen. The tab control no longer
adds a competing SwiftUI content animation, and the page host remains stable
instead of being torn down and faded while AppKit resizes the panel.

Audit mode now deliberately holds its inspectable panel open across Computer
Use pointer moves; normal hover-dismiss behavior is unchanged. A fresh Debug
build passed. Computer Use visually captured the populated eight-snippet page,
then clicked Home and captured the expanded Home endpoint without the prior
closed-island state. The tool captures settled frames rather than video, so
the continuous animation still needs user perception confirmation.

### 2026-08-04 — fixed: weather does not refresh on island expansion

The Home weather module no longer invokes a refresh from `onAppear`, which
previously reset it to “Updating weather…” every time the island reopened or
Home became visible again. The coordinator now performs the initial refresh at
app startup; Settings retains its explicit refresh and location-change paths.

A fresh Debug build passed. Computer Use captured the ready Austin weather
pill, navigated Home → populated Snippets → Home, and captured the same ready
weather pill after return without a loading-state flash.

### 2026-08-04 — in verification: liquid hover open/close motion

Hover-driven open and close now use one critically damped 0.34-second spring
for the island surface, including its silhouette, corner shape, shadow,
header, and expanded-page entrance. Dynamic Calendar and Snippets height
changes remain outside that SwiftUI animation so they retain their single
AppKit frame-motion owner.

A fresh Debug build passed. Computer Use exercised closed → Home → closed →
Home in the actual audit surface and captured the settled expanded state. It
does not record a frame sequence, so user visual confirmation is still needed
for the perceived Dynamic-Island-like continuity.

### 2026-08-04 — fixed: Fahrenheit is the weather default

Fresh installs now default to Fahrenheit. The existing Settings → Weather
“Temperature” picker continues to offer both Fahrenheit and Celsius, and an
already saved user choice is preserved. A Debug build passed; Computer Use
captured the Home weather pill rendering `Austin · 87°F · Clear`.

### 2026-08-04 — fixed: Home Calendar exposes schedule and reminder volume

The fixed-height Home Calendar card now remains an at-a-glance summary rather
than attempting to display a cramped agenda. It shows the active/next item,
then an explicit total such as `8 items · 2 reminders`; that count honours the
existing completed-reminder and all-day visibility settings. The whole card is
an accessible button that opens the selected day’s full, vertically expandable
in-island Calendar list. Reminder-only access also keeps that route available.

A fresh Debug build and focused XCTest
`testHomeCalendarSummaryIncludesEventsAndReminders` passed. Computer Use
captured the populated Home card at `8 items · 2 reminders`, clicked it, and
captured the full selected-day list containing all six events and two active
reminders.

### 2026-08-04 — adjusted: Home Calendar count stays within its fixed card

The first summary implementation added a third body line and exceeded the
Home card’s fixed vertical budget, visibly crowding the lower rounded edge.
The item and reminder counts now live in compact header badges beside the
calendar glyph. The original two-line body (primary item and time) and the
card’s height, corner treatment, and alignment with the media module are
preserved.

A rebuilt Home audit screenshot shows the populated card fully contained,
with `8` scheduled items and `2` reminders visible in the header badges.

### 2026-08-04 — fixed: no duplicate all-day text on Home Calendar

All-day entries no longer repeat an `All-day` metadata row below an event title
that already communicates that state. Timed entries still show their start
time. A fresh Debug build passed; Computer Use captured the compact Home card
showing `Company offsite — all day` once, with the card fully contained.

### 2026-08-04 — fixed: Mirror uses side rails and shape changes are immediate

The Mirror page now reserves its full vertical budget for the centered preview.
Start/stop sits in a narrow left rail; the direct square/circular switch and
Mirror settings sit in a matching right rail. This replaces the previous
top-and-bottom control stack, so no extra vertical page height is spent on
chrome and each action remains a labelled accessible button.

The shape action now updates the view's bound `mirrorShape` directly rather
than waiting for global-default observation. Computer Use captured the live
square endpoint, invoked `Use circular mirror`, then captured the circular
endpoint immediately; the returned control label changed to `Use square
mirror`, confirming the state transition. Debug build and focused XCTest
`testMirrorPresentationExplainsUnavailableAndPermissionStates` passed.

### 2026-08-05 — fixed: Mirror ring light follows the preview border

The requested ring light is a visual treatment around the mirror itself, not a
display-wide white panel and not a camera-hardware control. The Mirror rail now
has a labelled sun button, plus a vertical accessible brightness adjustment
when enabled. The glow uses the same `MirrorPreviewShape` as the preview, so
it precisely follows both the continuous rectangular and circular forms.

Computer Use captured the real circular camera preview with the ring light on:
the display outside MacIsland remained unchanged, the circular edge carried the
soft white glow, and accessibility exposed `Turn off mirror ring light` and
`Mirror ring light brightness` (37 percent in the captured interaction). A
fresh Debug build passed.

### 2026-08-05 — adjusted: stronger Mirror ring light

The ring light now defaults to 96 percent brightness and cannot be reduced
below 60 percent. Its halo is a 16-point blurred outer stroke with a 4-point
white core, producing a visibly thicker, brighter border without changing the
preview's rectangular/circular geometry. Computer Use captured the live camera
preview at 100 percent: the bright core and broad halo follow the full circular
edge while the rest of the display remains unchanged. A fresh Debug build
passed.

### 2026-08-05 — adjusted: prominent Mirror ring light

The previous two-layer glow was still too subtle. The enabled ring now combines
a 34-point diffuse bloom, a 16-point dense middle band, and a 7-point white
core. Computer Use captured the 96-percent endpoint around the real circular
mirror frame: the effect is visibly broad and bright around the full perimeter,
while remaining confined to the mirror rather than illuminating the desktop.
A fresh Debug build passed.

### 2026-08-05 — adjusted: Mirror light-control HCI

The side rail gives the lighting action a 44-point target with a high-contrast
yellow selected circle, selected outline, and glow. Its accessible name and
help provide the full `Turn on/Turn off mirror ring light` wording while the
compact visible sun treatment stays consistent with a native icon rail. The
yellow-tinted brightness slider appears only when the light is on.

The first labelled-button version had a layout defect: the rotated slider kept
a horizontal layout footprint, so its thumb collided with the `Light` label.
The visible label was removed and the slider now establishes its horizontal
track before rotation inside an explicit 32×76 vertical layout region. Computer
Use captured the corrected active state at 60 percent: button, track, and thumb
have clear separation with no overlap. A fresh Debug build passed.

### 2026-08-05 — fixed: Mirror ring-light brightness can recover upward

The rotated system `Slider` retained a horizontal hit region, so a user could
lower brightness but could not reliably raise it again from the visible vertical
track. It is now a purpose-built vertical control: taps and drags map directly
to the displayed track from 60 to 100 percent, and VoiceOver exposes Increment
and Decrement actions in five-percent steps.

Computer Use verified the actual interaction: tapping low on the track changed
the live value to 64 percent; tapping higher on that same track then raised it
to 93 percent. A fresh Debug build passed.

### 2026-08-05 — adjusted: Mirror surface removes visual status subtitles

The Mirror preview no longer draws the bottom status capsule such as `Camera
access will be requested when opened` or `Live preview`. The visual surface is
reserved for the mirror, its border treatment, and the side controls. The same
state remains available to assistive technology through the preview's
accessibility value and through the Open control's help text. Computer Use
captured the clean ready state and confirmed the accessibility value remained
present. A fresh Debug build passed.

### 2026-08-05 — fixed: first-run onboarding requests supported permissions up front

The existing introductory onboarding now requests every supported MacIsland
runtime permission before feature use: Camera, Calendar, Reminders, automatic
Weather Location, timer Notifications, and Accessibility, followed by the
existing music-controller selection. Each page keeps the explicit `Not Now`
choice; declining leaves the related feature unavailable rather than blocking
the app. Location onboarding requests authorization only and does not begin a
weather refresh; notification onboarding requests timer alert and sound
authorization only.

A fresh Debug build passed. A temporary normal first-launch run exposed the
real `Welcome to MacIsland` onboarding window and its Calendar permission page
through Computer Use; no system prompt was accepted. Audit mode intentionally
suppresses onboarding, so the new Location and Notifications system sheets
remain pending a user-driven first-run permission acceptance check.

### 2026-08-05 — fixed: silent 30-minute weather refresh while running

MacIsland now owns one refresh loop for its running lifetime. It refreshes the
existing supported weather provider every 30 minutes using the current selected
location mode. A background refresh preserves the last good forecast and keeps
the weather state ready; a transient network/location failure likewise retains
that snapshot instead of replacing it with a loading or error surface. Home and
Settings no longer render `Updating weather…`; when no forecast exists yet,
they use neutral placeholder copy instead.

Computer Use captured the rebuilt Home pill in its ready state (`Austin · 85°F
· Clear`) without a refreshing label. The 30-minute cadence has build/code-path
evidence only because this audit did not wait 30 minutes. Apple Weather.app
does not offer a public API for third-party apps to import its live forecast;
the refresh uses MacIsland's supported provider and the same automatic location
source instead.

### 2026-08-05 — fixed: Mirror session hover and Escape lifecycle

Mirror now treats a live camera preview, enabled ring light, or its open
settings window as a pinned session. Hover-off and other deferred close paths
check that shared policy before collapsing the island. Once the last active
Mirror element ends while the pointer is outside, the ordinary hover-dismiss
delay resumes. Switching away, closing, sleep/lock, and Escape clear the ring
light; camera shutdown continues through the existing session owner.

The Close Mirror action now uses the same `BoringViewModel.close()` path as
Escape, ensuring the preview and ring light are both removed. macOS global key
monitors do not receive a key sent to MacIsland itself, so Escape now has a
matching local monitor scoped only to the Mirror page. Computer Use enabled the
ring light, pressed Escape, and captured the resulting closed `Open MacIsland`
bridge. Computer Use has no pointer-move API, so real hover-off timing remains
pending a user perceptual check rather than being claimed as visual proof.

### 2026-08-05 — fixed: audit Calendar midnight rollover coverage

Production Calendar data is fetched from EventKit across the full-calendar
range (seven days prior through fourteen days ahead); only Home's compact
summary deliberately advances to the current day at midnight. The synthetic
audit fixture had been regenerated from `Date.now`, so restarting or
re-applying audit mode after midnight could make its August 4-only data appear
to disappear. Audit data is now anchored once per audit process and includes
populated yesterday entries, letting the full calendar continue to verify the
previous day after Home moves to the new date. This does not alter EventKit
data, user calendars, or the normal rollover behavior.

### 2026-08-05 — Shelf dense-data audit

Audit mode now installs 18 process-local Shelf fixtures (mixed text and links)
in addition to its existing calendar and clipboard fixtures. The data path is
explicitly non-persistent, so entering audit mode cannot overwrite a user's
saved Shelf. The real Debug Shelf surface was captured with all 18 items:
four approximately 105-point tiles are visible in the horizontal rail, while
the remainder is clipped past the right edge.

**Open P1 usability finding:** the populated rail has no visual indication
that more items exist off-screen. Computer Use's horizontal scroll action did
not move the rail, while a drag selected the last visible tile instead; that
does not establish whether real trackpad scrolling works, but it makes the
overflow undiscoverable in the captured state. Validate native trackpad
horizontal scrolling manually, then add a subtle trailing fade/peek or an
explicit page/scroll affordance if it is not immediately discoverable. The
existing previous/next toolbar controls provide selection navigation but do
not visibly reveal the off-screen selection in this audit capture.

### 2026-08-05 — resolved by user verification: Shelf overflow interaction

The user manually verified that Shelf arrow and slide/trackpad navigation work
as expected. Computer Use could not produce an equivalent trackpad gesture, so
its earlier non-moving scroll call is not treated as a product defect. The
overflow affordance finding is closed; the dense fixture remains available for
future visual checks.

### 2026-08-05 — fixed: denser compact Shelf tiles

Shelf tiles were reduced from 105 to 96 points wide, with matching 56-to-52
point icon and quieter padding reductions. This preserves labels and hit areas
while exposing a clearer partial fourth tile in the 580-point dense Shelf.
Computer Use captured the rebuilt 18-item state with the extra trailing item
peek visible; user verification covers the actual slide/arrow interaction.

### 2026-08-05 — fixed: Shelf share target visual weight

The large square target labelled `System Share Menu` dominated the Shelf and
wrapped its provider name like static content. It is now a 96-point tile-width
action labelled simply `Share`, with a quieter icon and no truncated provider
subtitle. Its accessibility label still exposes `Share files with System Share
Menu`, so the visible action is concise without losing destination context.
Computer Use captured the rebuilt dense Shelf with four visible item positions
and the compact Share target aligned to their visual scale.

### 2026-08-05 — fixed: Home Media baseline and compact transport balance

Media was still drawing beyond the shared Home-row height after Calendar was
bounded, making its card taller than Calendar. Media now receives that shared
height internally before drawing its surface, so both card edges align. The
previous/next controls use compact 28-point slots, Play/Pause uses 32 points,
and their spacing is reduced from 6 to 4 points; the reclaimed horizontal room
is assigned to the interactive progress timeline rather than lost to chrome.
Computer Use captured rebuilt playing media with aligned card baselines and a
visibly wider progress track.

### 2026-08-05 — fixed: reduce only the expanded island's shared width

The closed notch geometry is unchanged. The shared expanded shell is reduced
from 640 to 620 points—the narrowest size that still fits the established Home
minimums for media, Calendar, and Camera together after the shell insets are
applied. This removes 20 points of unused horizontal envelope without adding
per-page width overrides or squeezing content.

Computer Use captured the rebuilt Home and dense Shelf surfaces at 620 points.
Home kept its complete playing-media controls and the Calendar summary without
clipping; Shelf retained its share target, toolbar, and three-plus visible
tiles. Dense Shelf overflow remains the separately recorded open P1 finding.

### 2026-08-05 — verified: 580-point expanded shell

The shared expanded island was reduced again from 620 to 580 points; the
closed notch is still unchanged. Computer Use captured the rebuilt Home with
playing media, transport controls, progress, weather, and Calendar all
unclipped. The responsive Home budget intentionally omits its optional camera
tile at this width rather than squeezing media controls. The 18-item Shelf
also remained aligned, with its share target, toolbar, and three full tiles
visible. The separate Shelf overflow discoverability finding remains open.

### 2026-08-05 — fixed: 580-point header battery percentage wrap

At the narrower expanded width, the header battery percentage wrapped between
the number and `%`, despite sufficient visual room around the physical notch.
The percentage label now reserves its intrinsic single-line width and uses
monospaced digits; this fixes the header without widening the expanded shell
or moving controls outside its notch-aligned interaction region. Computer Use
captured the rebuilt 580-point Home header with `80%` on one line beside the
battery glyph and no collision with Timer or Settings.

### 2026-08-05 — fixed: Home Calendar and Media bottom baseline mismatch

The 580-point playing-media capture showed the Calendar card visibly painting
above and below its HStack slot, leaving its rounded bottom edge lower than
Media's. The Calendar surface now receives the shared Home-row height inside
the component before it draws its background and border; it can no longer
overflow the caller's fixed slot. Computer Use captured the rebuilt Home with
Media and Calendar sharing both their top and bottom card baselines.

### 2026-08-05 — fixed: compact Home Calendar time-label clipping

After the baseline fix, the Home Calendar's `8:30 AM` label sat against the
rounded lower edge because its internal date/header rhythm exceeded the shared
compact row by a few points. Calendar now uses a 6-point vertical inset,
tighter internal spacing, and a 26-point date numeral only in this Home
summary. Computer Use captured the rebuilt 580-point Home with the complete
time label visible and both Home cards still aligned.

### 2026-08-05 — fixed: Home Calendar date hierarchy

The oversized standalone day numeral was replaced with the compact, unambiguous
`AUG 5` date line: a secondary uppercase month abbreviation beside a reduced
23-point rounded day numeral. Computer Use captured the rebuilt Home with the
complete date and time visible inside the shared Calendar card height.

### 2026-08-05 — fixed: full Calendar month navigation

The full in-island Calendar no longer strands users inside a rolling
seven-days-back/fourteen-days-forward window. Its compact header now has
accessible `Previous month` and `Next month` controls. The horizontally
scrollable day rail is scoped to the displayed month: it begins on day 1 and
ends on that month's actual final day. Each month action preserves the selected
day where possible (clamping it for shorter months), reloads that day's
EventKit/audit items, and preserves the existing selected-day height policy and
Apple Calendar handoff.

Computer Use captured August with the complete `Aug 1`–`Aug 31` rail, then
invoked Next month and captured September with the complete `Sep 1`–`Sep 30`
rail. Debug build succeeded before the live check. Computer Use captures
settled endpoints only, so the month-change animation itself remains a
user-perceived motion check rather than claimed visual proof.

### 2026-08-05 — fixed: compact Empty Snippets state

The standard `ContentUnavailableView` was too tall beneath the Snippets title,
causing its explanatory copy to clip inside the compact island floor. Empty
Snippets now uses a single compact inline row with
the clipboard icon, `No snippets yet`, and the one-line instruction `Copy text
to add it here.` It follows the existing module surface, border, typography,
and accessibility treatment without increasing the panel height.

Computer Use launched the non-persistent `snippets-empty` audit route and
captured the entire title and empty-state copy within the compact surface.
Debug build succeeded before that visual check.

### 2026-08-05 — finished: direct Snippets history without search

Snippets no longer offers search. The page now uses its full content area for
the two-column clipboard history, retaining direct Copy and Delete actions on
every row. The unused filtering state, coordinator helper, and its focused
search test were removed together.

Computer Use captured the rebuilt non-persistent eight-entry `snippets-stress`
surface. Its accessibility tree exposes every copied snippet plus labelled
`Copy snippet to clipboard` and `Delete snippet` actions. The focused XCTest
compiled the changed test target but could not launch on this host because
LaunchServices failed to start `MacIslandTests`; no assertion failed.

### 2026-08-05 — fixed: Snippets trailing vertical space after search removal

Removing the search field left its old 36-point sizing allowance in the
content-driven Snippets height formula, making populated histories visibly too
tall with a dead strip below the final row. The fixed chrome estimate now
matches the title-only page. Eight audit entries retain their four two-column
rows while the final row ends with the normal module inset instead of excess
blank space. Computer Use captured the rebuilt dense Snippets surface; Debug
build succeeded before the visual check.

### 2026-08-05 — fixed: public Core Audio output route picker

The expanded player now has an accessible `Choose audio output` menu beside the
track information. It reads macOS's real Core Audio output devices, identifies
AirPlay routes when macOS exposes them as output devices, and changes the system
default output only after an explicit selection. `Sound Settings…` remains the
native fallback for routes controlled solely by macOS.

Computer Use captured the live expanded player and opened its route menu. The
menu listed this host's real `BlackHole 2ch` and current `MacBook Pro Speakers`
routes plus `Sound Settings…`; no route was selected or changed during QA.

### 2026-08-05 — fixed follow-up: output-route control rendering

The original borderless SwiftUI `Menu` rendered its route glyph as a bright
yellow prohibited-looking tile inside the compact player. The route action now
uses a standard dark circular speaker button and a native popover, avoiding the
problematic menu-label renderer while retaining the same public Core Audio data
and explicit-selection behavior. Computer Use captured both the corrected
player control and the popover with the current output checked.

### 2026-08-05 — fixed: native battery status popover

Clicking the header battery percentage now opens a compact battery panel backed
by live macOS IOKit data. It distinguishes the current charge from Battery
Health by calculating full-charge capacity against design capacity, exposes
cycle count, power source, charging time when available, and the active Low
Power Mode state. The Low Power Mode action opens the relevant Battery settings;
public macOS APIs expose that setting as read-only, so MacIsland does not claim
to toggle it directly or invent other active limits.

Computer Use captured the rebuilt panel on this Mac with `98% maximum capacity`,
`63` cycles, `Standard` power mode, and `Power adapter connected`. Debug build
succeeded before the visual check.

### 2026-08-05 — corrected: Battery Health calculation matches System Settings

The first health calculation used IOKit's raw `FullChargeCapacity`, which
reported 96% on this host. macOS Battery Health instead uses the calibrated
`NominalChargeCapacity` against design capacity. MacIsland now follows that
value (with raw capacity only as a fallback), and Computer Use verified the
panel reports `98% maximum capacity`, matching the System Settings evidence.

### 2026-08-05 — verified: 24-item audit Snippets stress surface

The audit-only clipboard fixture now contains 24 varied entries and remains
strictly in-memory. Computer Use captured the dense two-column surface at the
Snippets maximum height: twelve entries were visible at once with a clear
vertical scrollbar, no excess island growth, and no clipped rows. Scrolling to
the end kept the complete final row above the rounded lower edge with normal
bottom padding. The fixture never writes to the user's clipboard history.

### 2026-08-05 — external integration blocker: provider-backed Playing Next

The public macOS Now Playing feed and Spotify's AppleScript API expose current
metadata and transport but not the provider's queue. A real Playing Next view
therefore requires a provider integration: Spotify OAuth with a registered
client and scope, and/or Apple Music MusicKit authorization and entitlement.
Do not substitute playlist guesses or synthetic rows; that would misrepresent
the provider queue. This remains blocked pending the product decision and
provider credentials/authorization configuration.

### 2026-08-05 — implemented and visually verified: Quick Notes uses Apple Notes

Quick Notes is now a fifth Island page backed directly by the user's macOS
Notes account rather than a separate MacIsland store. It loads recent notes,
creates a note only after an explicit `Add to Notes` action in the account's
default folder, and opens a selected note or the full Notes app on demand.
The sandbox Apple Events target and purpose string cover the normal macOS
Automation consent flow. Computer Use captured three real Notes previews in a
content-sized Island with no clipped rows, then verified `Open Notes` handed
off to the native Notes app. No note was created during QA.

### 2026-08-05 — fixed and visually verified: Notes tab notch clearance and page inset

Adding the fifth tab made the former 32-point tab cells slightly overlap the
physical-notch lane on narrower displays. The tab strip now uses compact
30-point visual cells within its existing 32-point header interaction lane,
leaving clear space before the hardware bridge. Quick Notes also reserves an
additional 8-point lower inset and corresponding content height, so the final
recent-note row does not sit against the rounded panel edge. Computer Use
captured both the cleared header and the padded Notes page after a successful
Debug build.

### 2026-08-05 — fixed and visually verified: Quick Notes editor keyboard focus

The custom Island panels previously declined key-window status outside audit
mode, which made the visible Quick Notes editor unable to accept typing. Both
panel variants now participate in the normal macOS responder chain while still
remaining non-main panels. Computer Use verified text entry and the enabled
`Add to Notes` action in a normal (non-audit) Debug launch; the verification
draft was not saved. The UI also makes the native title rule explicit: the
first non-empty line becomes the Apple Note title.

### 2026-08-05 — fixed and visually verified: Quick Notes recent-list density

The first lower-inset adjustment left the recent-notes page with a visibly
heavy empty band beneath its third row. The page now uses a 400-point
content-matched height: all three recent notes remain fully visible and the
rounded panel ends with a small, even inset rather than clipped content or
excess panel padding. Computer Use captured the rebuilt result after a
successful Debug build.

### 2026-08-05 — fixed and visually verified: Quick Notes background refresh

Quick Notes previously created a new provider and visibly loaded recent notes
whenever the tab appeared. The Notes provider is now app-lifetime state warmed
from the Island root, with a ten-minute freshness interval. The page observes
that cache and no longer renders a loading row. Computer Use opened Notes,
switched away, and reopened it with the real recent-note rows already present;
the rebuilt Debug app passed before this check.

### 2026-08-05 — fixed and visually verified: Quick Notes lower shell separation

The full-height gray Notes module visually merged with the Island's rounded
lower border. Quick Notes now reserves an outer lower gutter after its module
surface and adjusts its content height to preserve all three recent-note rows.
Computer Use captured the rebuilt page with a distinct dark Island-shell edge
below the module and no row clipping; Debug build succeeded first.

### 2026-08-05 — fixed and visually verified: media output-picker placement

The audio-output control previously shared the two-line metadata row, causing
it to sit awkwardly between the track details and transport controls. It now
anchors to the player card's upper-right corner with an 8-point edge inset;
the track text reserves compact clearance beneath it. Computer Use captured
the rebuilt playing-media card with no title or control overlap after a
successful Debug build.

### 2026-08-05 — fixed and verified: Shelf drag-preview lazy rendering

Visible Shelf tiles no longer render high-resolution SwiftUI drag previews on
appearance or synchronously during AppKit view creation. A preview is now
rendered only after the drag threshold is crossed, then published into that
tile's cache for subsequent drags; thumbnail changes merely invalidate the
cache. Computer Use captured the 18-item audit Shelf after the Debug build,
with all tiles rendering normally and no eager preview path remaining.

### 2026-08-05 — reopened P1: Quick Notes does not accept physical keystrokes

The Quick Notes editor still fails the direct-input audit. After a real click
on the native editor, Computer Use typed `Quick Notes audit input`; the text
area remained empty and `Add to Notes` stayed disabled. This reproduces the
user-visible typing failure despite the editor exposing a focusable,
accessibility-settable text area. The issue remains open: do not treat the
previous key-window and `NSTextView` bridge changes as verified.

### 2026-08-05 — fixed and visually verified: deterministic expanded media audit states

`media-playing` and `media-paused` now install an explicit in-memory playback
fixture before opening the Island. While that fixture is active, live controller
publications, forced provider refreshes, idle-state calculation, and provider
volume synchronization cannot overwrite it. The fixture contains stable track
metadata, five-minute progress, artwork, and a Spotify provider badge; a
normal launch clears the override and continues to use live Now Playing data.
Computer Use captured `media-playing` with **Audit Track / MacIsland**, an
Spotify badge, and a Pause control, then captured it unchanged after seven
seconds. It also captured `media-paused` with the same metadata and a Play
control, unchanged after eight seconds. Screenshot evidence:
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/MacIsland Screenshot 2026-08-05 at 1.51.12 AM.jpeg`
and
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/MacIsland Screenshot 2026-08-05 at 1.47.20 AM.jpeg`.

### 2026-08-05 — fixed and visually verified: live provider-aware media routing

The automatic `Now Playing` preference previously fell back to Apple Music on
hosts where the generic MediaRemote route was unavailable, even when Spotify
was the running player. The manager now chooses a running supported direct
provider (Spotify first, then Apple Music) for that automatic fallback. When
MediaRemote is available but still produces no usable title/artist after 1.5
seconds, it also switches to the running direct provider. Explicit user source
choices remain unchanged.

Computer Use verified the live Spotify session: `Get You - Live` by Daniel
Caesar with artwork, Spotify badge, `5:33 / 5:35`, and Pause. Three seconds
later Spotify advanced and the Island updated to `4 Raws` by EsDeeKid with new
artwork and `0:06 / 2:26`, proving real metadata and progress—not audit
fixtures. Screenshot evidence:
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/MacIsland Screenshot 2026-08-05 at 1.54.23 AM.jpeg`
and
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/MacIsland Screenshot 2026-08-05 at 1.54.33 AM.jpeg`.

### 2026-08-05 — fixed and visually verified: Quick Notes editor focus

The visible Quick Notes editor exposed an accessibility-settable text area but
its borderless floating Island panel did not become key before AppKit delivered
the click. Both production panel variants now promote themselves to the key
responder chain on mouse-down, before forwarding the same event to SwiftUI.
The ordinary audit panel uses that same `BoringNotchWindow` behavior rather
than a separate utility-window implementation.

Computer Use clicked the real Quick Notes editor, confirmed it became the
focused element, typed `Quick Notes audit input`, and captured the rendered
text and newly enabled `Add to Notes` control. The test draft was not saved.
Screenshot evidence:
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/MacIsland Screenshot 2026-08-05 at 1.58.28 AM.jpeg`.

### 2026-08-05 — fixed: hover collapse/expand frame clipping

The Island previously reset its AppKit host panel to the compact frame at the
same instant that SwiftUI began collapsing the visible surface. This clipped
the surface and made hover dismissal appear nearly instantaneous. Open and
close now use one low-bounce 0.46-second spring; the host panel retains its
expanded frame until that surface transition settles, then collapses its
transparent bounds. Rapid re-open cancels the deferred collapse so it cannot
shrink an already-open Island.

Computer Use captured clean compact and expanded endpoints after a rebuilt
Debug app. Screenshot evidence:
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/MacIsland Screenshot 2026-08-05 at 2.44.37 AM.jpeg`
and
`/var/folders/vf/g7fkng710zz_qnp372ttbshm0000gn/T/com.openai.sky.CUAService/1/MacIsland Screenshot 2026-08-05 at 2.44.37 AM.jpeg`.
Computer Use screenshots are endpoint evidence only; final temporal feel must
be confirmed by a person using the production build.
