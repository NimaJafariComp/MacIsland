# MacIsland UI audit mode

UI audit mode is a test-only launch configuration for visual and accessibility
inspection when pointer-driven Computer Use is unavailable or incomplete. It
does not change normal MacIsland behavior, preferences, signing, or release
configuration.

## Launch

Build the app, then launch one isolated audit instance:

```zsh
open -n /absolute/path/MacIsland.app --args -uiAuditMode YES -uiAuditState home
```

`Scripts/prepare-ui-audit-state.sh` wraps this for supported states. It refuses
to run while *any* MacIsland instance is open: macOS can otherwise route a
same-bundle-ID audit launch to a different build. Quit the existing MacIsland
instance before preparing another state.

```zsh
Scripts/prepare-ui-audit-state.sh /absolute/path/MacIsland.app media
```

Audit mode uses a regular activation policy, makes the island panel key/main,
and uses readable window sharing so screen capture and accessibility clients
can retain an actionable window. The ordinary non-key overlay, accessory
activation policy, and the user's screen-recording preference are kept for
normal launches.

## States and shortcuts

After an audit-mode window is key, use these audit-only shortcuts. They are
Option-Command shortcuts and are intercepted only in audit mode.

| Shortcut | State | What it demonstrates |
| --- | --- | --- |
| Option-Command-1 | `closed` | Collapsed bridge, no synthetic activity |
| Option-Command-2 | `hover` | Forced hover geometry without a pointer-move API |
| Option-Command-3 | `home` | Expanded Home surface and tabs |
| Option-Command-4 | `shelf` | Expanded Shelf tab |
| Option-Command-5 | `timer` | Closed 10-second countdown timer activity |
| Option-Command-6 | `media` | Closed playing-media activity with audit metadata |
| Option-Command-7 | `camera` | Expanded camera module; shows its unavailable status when no camera permission/device exists |
| Option-Command-8 | `error` | Expanded deterministic weather-error presentation |
| Option-Command-9 | `accessibility` | Expanded Home with stable island/tab accessibility identifiers |

Every audit state first seeds in-memory Calendar events/reminders and eight
clipboard snippets. This makes cross-page navigation deterministic and never
writes to EventKit, the user's Calendar settings, or clipboard history.

`calendar-stress` (alias: `calendar`) is launch-only. It displays that
non-persistent mixture—including overlaps, an all-day event, long titles, and
completed reminders—on the Calendar page.

`calendar-home-stress` (alias: `calendar-home`) is launch-only. It keeps the
same dense fixture behind Home's summary card and makes the next timed event
deliberately long, so Home's title truncation, fixed height, and module spacing
can be inspected without personal calendar data.

`snippets-stress` (alias: `snippets`) is launch-only. It opens the seeded
eight-entry in-memory clipboard surface.

`dismissed` is an alias for `closed`; `expanded` is an alias for `home`.
Launch-only `mediaPlaying`/`mediaPaused` states (or `media-playing`/
`media-paused`) open Home with deterministic media metadata for transport and
progress inspection.
Every shortcut resets timer, camera expansion, and synthetic media before it
applies the selected state. No preference is written while doing so.

## Accessibility hooks

- `macisland.island`: the panel root; label changes between `Open MacIsland`
  and `MacIsland island`.
- `macisland.tab.home`, `macisland.tab.shelf`, `macisland.tab.snippets`:
  expanded tab controls.

Use the identifiers for inspection/assertions, not coordinate guesses. The
audit window is intentionally key so control tools can send the documented
shortcuts even when they cannot click a non-key overlay.

## Limits

The `hover` shortcut is a fallback visual state, not proof that macOS delivered
a real pointer hover. `prepare-ui-audit-state.sh ... hover` exercises the real
hover path only when Assistive Access and `cliclick` are available. A tool with
no pointer-move operation cannot independently verify hover enter/leave timing.

Camera state does not fabricate a camera feed. It exposes the real camera
module and its permission/device result. Real media integrations, Shelf files,
and external-app menu-bar collision testing still require their corresponding
host state.

UI audit mode is not a release feature. Do not ship, benchmark, or take product
screenshots from it without recording that the state was synthetic.
