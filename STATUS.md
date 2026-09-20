# Current status

2026-09-20: Offline multi-station cache: up to eight per-station boards, Cached fallback for the selected station, cached-age hints in recents. Watch suite: 16 tests pass.

2026-09-20: Controls polish: UP/DOWN cycle recent commutes, 30s refresh while a train is within five minutes, optional Train buzz setting. Watch suite: 15 tests pass. Physical buzz check still pending.

2026-09-20: Service alerts implemented on the watch (Alert tag, Stations menu list, paged detail view, glance `!`) and in the proxy (`alerts.py`, per-station alerts + `alerts_available`). Watch suite: 16 tests pass. The proxy is now deployed (release `20260920T160447-5b6db79`) and the public L03 board serves 7 alerts, but the watch build with the alert UI is not yet uploaded to Garmin (listing remains 0.3).

2026-09-20: Distance setting added (Walking time default, plus Meters/Feet/Miles), "Now" for sub-minute arrivals, entrance label centered without heading, plus terminal-name polish and the test-pollution fix. Watch suite: 13 tests pass. Simulator workflow and pitfalls recorded in FINDINGS.md.

2026-09-20: Cleanup pass. User confirmed the entrance build is installed on a physical FR965 and works relatively well; FINDINGS now records this. All 31 proxy tests pass on re-run; the watch suite runs 11 tests (18 `(:test)` annotations; seven on helpers), all passing. Production and signed export builds pass.

Garmin listing remains the previously uploaded version 0.3; this entrance update is GitHub-synchronized but has not been uploaded to Garmin.

GitHub: app code at `076ea29`; this docs cleanup commit is pushed on top.

Owner: none; no held resource locks.
Next action: upload 0.4 and invite a friend as a private beta tester once their watch model and Garmin account email are known; steps noted in FINDINGS.md.
