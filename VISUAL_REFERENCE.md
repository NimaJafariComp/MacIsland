# MacIsland visual reference contract

Source: six user-supplied visual references, 2026-07-29. They define the
intended interaction density and visual hierarchy for MacIsland. They are
references for behavior and composition only; MacIsland must not copy their
artwork, branding, or assets.

## Required states

1. **Music, weather, and calendar hub** — Home has a stable navigation strip
   below the hardware anchor and a compact, horizontally composed set of media,
   weather, and date modules.
2. **Quick camera access** — Camera is a first-class Home module with obvious
   preview and close/capture actions; its presence must not move the housing or
   navigation strip.
3. **Capture notes instantly** — Notes are a dense, scrollable card grid with
   clear add/search/sort actions and an active-page indicator.
4. **Smart timer and stopwatch** — A dedicated page exposes the large current
   value, start/add controls, mode switcher, and predictable preset grid.
5. **Smart clipboard and text snippets** — Snippets are compact, readable
   cards grouped in columns; search and add are persistent, discoverable
   actions.
6. **Drag-and-drop file management** — Shelf is a dedicated page with an
   obvious drop target, retained file state, and a separate AirDrop action.

## Non-negotiable visual rules

- The physical notch or synthetic anchor is immutable. Changing pages,
  modules, settings, active media, or hover state must never move, resize, or
  redraw the camera housing.
- Every expanded state is one quiet, rounded outer island anchored to that
  housing. Internal cards have consistent spacing and radii; they never look
  like separate windows touching the display edge.
- Header height, baseline, and side lanes are state-invariant. Page controls
  may change selection only; they may not wrap, create a second row, or change
  the island's vertical origin.
- Persistent controls are sparse: page navigation, a direct Settings action,
  and truly stateful utilities. Camera, timer, notes, and Shelf use their own
  pages rather than crowding the header.
- Transitions originate at the anchored housing, interpolate size and corner
  radius together, and settle without bounce or a one-frame snap. Reduce Motion
  uses the same endpoints without scale/bounce choreography.

## Review gate

Before visual work is accepted, inspect capture pairs for Home, camera, notes,
timer, snippets, and Shelf on the same display. The physical anchor's frame
must be identical across the pair, and each page must show a single rounded
outer surface with no top-edge collision.

The raw attachment files are retained by the current chat but are not available
as filesystem bytes to this agent. Attach them as files to archive their exact
PNGs in the repository; until then this contract and the in-chat images are the
authoritative visual reference.
