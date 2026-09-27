# Current status

2026-09-20: Walking-time estimate de-optimized for the city grid: `MtaFormat` applies a 1.3x grid detour to the straight-line distance (Meters/Feet/Miles stay raw). `MtaFormatTest.distanceFormatRules` updated plus a 368 m case; distance assertions pass; production and test builds compile. Not yet in a published build.

2026-09-20: v0.4 (Internal 4) published to the Garmin Connect IQ listing (status Pending) and installed on the physical FR965 (user-confirmed). Signed artifact `build/NycMta.iq`, SHA-256 `f38185863ddc8f1c4b4295e3d8cff05a15b330267b843a0489c41296e55857f3`, listing size 43 KB. What's New covers service alerts, the Distance setting, Now, UP/DOWN commutes, faster close-train refresh, optional train buzz, and offline per-station boards.

2026-09-20: Offline multi-station cache: up to eight per-station boards, Cached fallback for the selected station, cached-age hints in recents. Watch suite: 16 tests pass.

2026-09-20: Controls polish: UP/DOWN cycle recent commutes, 30s refresh while a train is within five minutes, optional Train buzz setting. Watch suite: 15 tests pass. Physical buzz check still pending.

2026-09-20: Service alerts implemented on the watch (Alert tag, Stations menu list, paged detail view, glance `!`) and in the proxy (`alerts.py`, per-station alerts + `alerts_available`). Watch suite: 16 tests pass. The proxy is now deployed (release `20260920T160447-5b6db79`) and the public L03 board serves 7 alerts, and the watch build with the alert UI is published as version 0.4 (Internal 4).

2026-09-20: Distance setting added (Walking time default, plus Meters/Feet/Miles), "Now" for sub-minute arrivals, entrance label centered without heading, plus terminal-name polish and the test-pollution fix. Watch suite: 13 tests pass. Simulator workflow and pitfalls recorded in FINDINGS.md.

2026-09-20: Cleanup pass. User confirmed the entrance build is installed on a physical FR965 and works relatively well; FINDINGS now records this. All 31 proxy tests pass on re-run; the watch suite runs 11 tests (18 `(:test)` annotations; seven on helpers), all passing. Production and signed export builds pass.

The Garmin listing is version 0.4 (Internal 4), published 2026-09-20 and installed on the physical FR965.

GitHub: synchronized at `bd294a3` before this docs update.

Owner: none; no held resource locks.
Next action: invite a friend as a private beta tester once their watch model and Garmin account email are known; steps noted in FINDINGS.md.
