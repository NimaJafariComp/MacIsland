# Task 6.2 performance profile

Host: MacBook Pro (`Mac17,2`), Apple M5, 24 GB RAM, macOS 27.0 (26A5388g),
built-in 3024x1964 Retina display at 120 Hz. The frame interval budget is 8.33
ms. Each capture attaches Instruments' Animation Hitches template for five
seconds; a hitch is a frame over 33 ms. `displayed-surfaces` XML is retained as
system-compositor context and is not reported as MacIsland-only FPS.

| State | Median / max CPU | RSS | >33 ms hitches |
| --- | --- | --- | --- |
| Idle closed | 0.0% / 0.0% | 23 MB | 0 |
| Hover | 0.0% / 0.0% | 23 MB | 0 |
| Open Home | 0.0% / 0.1% | 29 MB | 0 |
| Close settle | 0.0% / 0.0% | 29 MB | 0 |
| Settings | 0.0% / 0.0% | 62 MB peak | 0 |
| Camera mirror, live | 2.3% / 2.6% | 145 MB peak | 0 |
| Media, no active player | 0.0% / 0.1% | 76 MB peak | 0 |

`camera-live-state.png` confirms the live preview and the macOS green camera
indicator. `home-state.png` and `settings-state.png` confirm the open and
settings states. Every raw `top` sample, hitch export, surface export, and
`.trace` bundle is retained next to this record.

Measured tooling fixes: `Scripts/profile-ui-performance.sh` normalizes the
Instruments duration suffix, waits for the trace tables to become exportable,
and records peak RSS as well as CPU. No product hot path exceeded the stated
frame/hitch budget, so no speculative rendering change was made.

Limits: Spotify was installed but had no active playback session; no audio was
started solely for profiling. A real Finder drag/drop capture remains blocked by
an unrelated macOS app-control permission sheet, so active-media and drag/drop
measurements are not claimed here.
