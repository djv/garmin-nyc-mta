# Current status

2026-09-27: v0.7 published (listing shows Version 0.7, App pending BETA; What's New set). Glance Out Of Memory fix (the glance saves only the primary board via `BoardStore.savePrimary`; v0.4 crashed twice on 2026-09-25) plus polish:
- The glance picks the pack station nearest the watch's last known position (`LastFix`, <15 min old, e.g. the run just finished) and shows "7m Fort Ha..." over "Then 22m, 37m" (just "Then 22m" when both don't fit; the station name when only one train is left). Offline, the pack now beats a stale cached home board. It reads storage once per show (was every 5 s).
- On the board, the arrow and walk label are centred as one group (no bezel clipping), the meta line is wider, the scheduled meta drops the pack age, and "Jamaica" / "Bedford" are shorter.
- "Ago" now uses the shown board's own time (Cached boards showed the primary board's age). Refresh pacing and Train buzz use the shown board, so scheduled trains buzz too, and the board no longer reads storage every second.
- A pack arriving while "No GPS fix" is shown fills the board. `restorePack` also uses the last known position.

The live meta line now leads with the age ("7s ago | Saved GPS / Alert"), because long tags clip at the end.

18 tests pass (new `polishRules` covers the cached-board age, refresh pacing and buzz on the shown board, a late pack on "No GPS fix", the glance preferring the pack offline, and short names). Simulator, all verified:
- Live board online with the centred arrow and label.
- Offline cached board with the Offline tag.
- Late pack (sim-only build that delays the fetch): "No GPS fix" → 45 St scheduled.
- Offline glance and board both show the nearest pack station (Fort Hamilton Pkwy, G) via last known position; the destination is used with GPS unavailable.
- Glance memory 31.3/59.8 KB.

Offline board rows show the train's terminal, like the live board ("Bedford 9m"), from the pack's new `heads`/`h` fields (mta-proxy `d530a40`, deployed; older packs fall back to "by HH:MM"). Simulator: an offline glance and board at Fort Hamilton Pkwy showed "Then 23m" and G rows labelled "Bedford". Signed `build/NycMta.iq` (38,294 bytes), SHA-256 `1696b694a856209a946c0c41a6adbfbdb33b6560950d7242235e34546345c43e`, published as v0.7; install on the watch not yet confirmed. Not verified: on-device `Position.getInfo` after a real activity.

2026-09-26: Offline pack board now shows the pack station nearest the GPS fix at any distance (was: within 1.5 km, else the run's destination), with the entrance arrow and walking time; destination only without a fix. 17 tests pass; simulator at a Prospect Park fix showed Parkside Av, ~13 min, Q rows 2m/14m/24m/42m. Signed `build/NycMta.iq` SHA-256 `b235ccd3fa8779e3121d09426e996730d2b01251cd8ba157e6ab32f0d6587dea` published 2026-09-27 as v0.6 (Internal 6, listing 47 KB) and installed on the FR965 (GarminDevice.xml lists NYC MTA Version 6). Pack key is set in the Connect app; the watch fetched the pack (proxy log 2026-09-26 23:10).

2026-09-26: Run pack for phone-free run-and-ride: `PackStore`/`PackService` (background temporal event every 15 min, `Background` permission), `packKey` setting, offline board fallback (`Sched home`, `by HH:MM` door time) and glance fallback. Watch suite: 17 tests pass (new `packStoreRules`; `locationLifecycle` now isolates the stored pack). Simulator: with BLE Not Connected the board showed the real 45 St pack counting down, and the glance showed the next scheduled R. Not verified: the background temporal event itself (simulator menu), on-watch behaviour. Signed `build/NycMta.iq` SHA-256 `6b1430625a3c82a89216a510e6f15473a0d2bbd90bccdc7a5cc42207a4a6f29e` published as v0.5 (Internal 5, listing 46 KB, Pending BETA); install on the watch not yet confirmed. Proxy side deployed (mta-proxy `61d8e8c`).

2026-09-20: Walking-time estimate de-optimized for the city grid: `MtaFormat` applies a 1.3x grid detour to the straight-line distance (Meters/Feet/Miles stay raw). `MtaFormatTest.distanceFormatRules` updated plus a 368 m case; distance assertions pass; production and test builds compile. Not yet in a published build.

2026-09-20: v0.4 (Internal 4) published to the Garmin Connect IQ listing (status Pending) and installed on the physical FR965 (user-confirmed). Signed artifact `build/NycMta.iq`, SHA-256 `f38185863ddc8f1c4b4295e3d8cff05a15b330267b843a0489c41296e55857f3`, listing size 43 KB. What's New covers service alerts, the Distance setting, Now, UP/DOWN commutes, faster close-train refresh, optional train buzz, and offline per-station boards.

2026-09-20: Offline multi-station cache: up to eight per-station boards, Cached fallback for the selected station, cached-age hints in recents. Watch suite: 16 tests pass.

2026-09-20: Controls polish: UP/DOWN cycle recent commutes, 30s refresh while a train is within five minutes, optional Train buzz setting. Watch suite: 15 tests pass. Physical buzz check still pending.

2026-09-20: Service alerts implemented on the watch (Alert tag, Stations menu list, paged detail view, glance `!`) and in the proxy (`alerts.py`, per-station alerts + `alerts_available`). Watch suite: 16 tests pass. The proxy is now deployed (release `20260920T160447-5b6db79`) and the public L03 board serves 7 alerts, and the watch build with the alert UI is published as version 0.4 (Internal 4).

2026-09-20: Distance setting added (Walking time default, plus Meters/Feet/Miles), "Now" for sub-minute arrivals, entrance label centered without heading, plus terminal-name polish and the test-pollution fix. Watch suite: 13 tests pass. Simulator workflow and pitfalls recorded in FINDINGS.md.

2026-09-20: Cleanup pass. User confirmed the entrance build is installed on a physical FR965 and works relatively well; FINDINGS now records this. All 31 proxy tests pass on re-run; the watch suite runs 11 tests (18 `(:test)` annotations; seven on helpers), all passing. Production and signed export builds pass.

The Garmin listing is version 0.6 (Internal 6), published 2026-09-27; v0.4 is the last build confirmed on the physical FR965.

GitHub: synchronized at `bd294a3` before this docs update.

Owner: none; no held resource locks.
Next action: confirm v0.7 on the watch (GarminDevice.xml Version 7); check the glance and board offline on a real run; then invite a friend as a private beta tester once their watch model and Garmin account email are known; steps noted in FINDINGS.md.
