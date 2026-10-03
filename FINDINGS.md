# Findings

## Nearby startup and keys — 2026-10-02
- User asked to check run readiness, then requested Nearby on startup and UP/DOWN cycling the nearest stations. BoardView now uses the five nearest bundled official complexes, with `_nearbyStation` separate from explicit `selection` so periodic GPS continues. New launches show the nearest static board first with a recent watch position; without one, a cached board remains explicitly Last station. Recent commutes stay in the menu and cycling does not save recents.
- Regression coverage: startup ignoring an unrelated cached station, offline cycling/wrap, no recents, clearing explicit filters, stale async responses, same-name/wrong pack rejection, live direction-option preservation, route/entrance filtering, moving outside the old five, GPS cadence and no-fix state. All 21 watch tests passed after final code changes. MonkeyDo still exits 1 even with `PASSED (passed=21, failed=0, errors=0)`.
- Simulator isolated on Xvfb :19 (downloaded/extracted Xvfb to `/tmp/mta-nearby-qa/xserver`, no system install or desktop focus). Production app at 40.7033,-74.0170 with BLE disconnected: initial Bowling Green, actual DOWN button South Ferry, actual UP Bowling Green; entrance arrow/walk time visible and app memory about 65/763.6 KB. Screenshots `/tmp/mta-nearby-qa/nearby-board.png`, `nearby-down.png`, `nearby-up.png`. Test and signed export builds also passed. Package hashes/size in STATUS.md.
- Public backend verified Oct 2 ~22:32 ET: health, home/Hudson W22/Battery boards and timetable reach all successful; no failed feeds/partial boards; live GTFS timestamps 1–8 s old. Hetzner release `20260927T114409-d530a40`, zero restarts, 93 successful health checks over prior eight hours; timetable refreshed 18:48 ET.
- Backend same-name/<300m merging can conflate separate stations (e.g. 23 St at 7th/8th Ave); the client guards Nearby live/cached/pack rows and entrances using canonical bundled route sets before cache saves. Matching uses exact IDs, not names. Express aliases retain their display labels. Because the proxy clamps arrivals to eight before filtering, valid predictions can be omitted; affected boards show Partial. No backend deployment performed.
- Official Garmin primary docs: https://developer.garmin.com/connect-iq/articles/core-topics/Application_and_System_Modules.html (HTTP 200; same text in SDK 9.2.0 `doc/docs/Core_Topics/Application_and_System_Modules.html`) supports launching from the glance list during native activity recording and warns GPS may be denied while another app records. Physical Run continuity/GPS access and installed version remain unverified; no USB watch connected. Last recorded hardware install is v0.6; v0.7 published; this v0.8 candidate unpublished. Prior source/assets/docs WIP preserved, no commit/publish/install performed.

## Bundled offline stations — 2026-09-29
- Sources: MTA Subway Stations CSV (data.ny.gov `39hk-dx4f`, 496 rows, retrieved 2026-09-29, pinned as `tools/data/Stations.csv`, SHA-256 `42ae7c7e...41f1`); the old `web.mta.info/.../Stations.csv` still serves an older column layout. Entrances: mta-proxy `data/entrances-2024.json` (2024 snapshot, entry_allowed=YES only). GTFS static: mta-proxy `google_transit.zip`, feed 2026-05-26..2026-10-31 (`20260826-X-long-term-supplement-trip-ids`). Full provenance in `resources/stations/meta.json`.
- 258 platforms within 10 km of 40.73339,-73.99367 merge into 229 stations by (Complex ID, stop name): Union Sq's L/456/NQRW become one, while Times Sq-42 St and 42 St-Port Authority, or Chambers St and Park Place, stay apart. "14 St" (1 2 3 at 7 Av + F M at 6 Av) is one station 340 m wide; its entrances fix the arrow.
- Direction labels (24 distinct) are short in this dataset ("Uptown", "Downtown", "Manhattan", "Outbound", "Queens"...), not "Uptown & The Bronx". "Last Stop" is blanked (no departures that way).
- Home rule = the proxy's: GTFS stops within 700 m of home (14 St-Union Sq, 8 St-NYU, Astor Pl, 6 Av, 14 St F/M, W 4 St, 3 Av). 14 St 1 2 3 (7 Av, 740 m) is not a home stop, so the 2/3 from Clark St give "No direct train home"; High St (A C) nearby does. A line counts in a direction when at least 50% of its trips departing that platform 06:00-21:00 later stop at a home stop (drops night-only patterns). 79 of 229 stations have no one-seat ride.
- Format: `idx.json` flat `[lat_e5, lon_e5, ...]` (3.9 KB, nearest home first); `cNN.json` 16 records `[id, name, lat_e5, lon_e5, groups, entrance deltas, home]`, groups flat by 5 (routes, N label, S label, home routes N, home routes S). Index and chunks are `scope="glance"` jsonData, loaded with `Application.loadResource`; `source/StationData.mc` is generated. Max 28 entrances and 4 groups per station.
- Memory (simulator, sim-only build printing `System.getSystemStats().usedMemory`): glance 26.4 KB before the lookup, 28.8 KB with the index, 32.1 KB with a chunk, 36.2 KB after building Times Sq (16 entrances), 26.5 KB after; so ~10 KB transient on top of the glance's worst case (31.3 KB with pack and board) stays under 59.8 KB. App board 50 KB, Offline stations menu 58 KB of 763.6 KB. Signed .iq grew 38.3 → 53.7 KB.
- FR965 FONT_XTINY fits ~26 characters across the meta line; "Offline | Home: C E Downtown" clipped, so the ride home is the meta line and "Offline map" moved to a footer at 0.89 h. Six direction rows at 0.075 h spacing (bullets r=14) fit; Times Sq's 7th row (S) is dropped.
- Simulator driving on Xephyr :9: `xdotool type` into the Set Position dialog only works after clicking the field and with `--clearmodifiers`; the simulator crashed once while switching BLE to Connected (restart fixed it; GPS quality resets to Last Known/none after a restart). `pgrep -f MonkeyDoDeux` in a compound command matched and killed the calling shell again: filter `pgrep -x java` by `/proc/PID/cmdline`.

## v0.7 polish: glance nearest station, storage reads, clipping — 2026-09-27
- `Position.getInfo()` works in the glance scope; the simulator's Set Position feeds it. The glance uses it to pick the nearest pack station.
- The glance previously re-read the board (several times) and the pack from Storage on every 5 s redraw. Each read copies the whole value into the 60 KB glance heap. It now caches both per show. Simulator glance memory offline with a pack: 31.3/59.8 KB.
- The board read `BoardStore.load()` every second (refreshDelay, maybeBuzz, meta age) and `PackStore.ageSeconds()` (the whole pack) every second when scheduled. It now uses in-memory `_boardArrivals`/`_boardTime`.
- FR965 FONT_GLANCE fits about 10 characters beside the route badge. The glance primary line reads "7m Fort Ha..." and the second line "Then 22m, 37m", or "Then 22m" when that does not fit.
- Board meta line: the chord at y=0.31h is about 420 px, so it now clips at w-70 (was w-120).
- Terminals: the supplemented GTFS has `trip_headsign` on every trip (0 empty). The pack adds per station `heads` (unique terminals) and `h` (one index per departure). The real 4-station pack grew to 3,541 bytes, under the 4 KB cap.
- A flaky polishRules failure happened once, only when the simulator had a GPS fix: the glance picked Parkside, which had one train in the fixture, so no "Then". The test now checks every pack station explicitly.
- The glance refreshes only when its cached board is 60 s or older (or a direction is selected). With a fresh (<60 s) live board it keeps showing it for up to a minute after going offline, then switches to the pack. Mid-run the cache is old, so the switch is immediate.
- Simulator: File > Reset All App Data did not clear Storage here. For a clean start, use a sim-only build that deletes keys in `onShow`. Settings > Set GPS Quality > Not Available gives "No GPS fix".
- Simulator BLE: Settings > Connection Type > BLE > Connected / Not Connected. It stayed "Not Connected" from the earlier session, which showed "Check phone link".

## Run pack — 2026-09-26

Goal: show trains home mid-run without the phone (FR965 has no LTE; Connect IQ web
requests only go through the phone). Pack format from the proxy: per station
`d = [departure epoch, route index, minutes to the door, ...]`, ~3 KB for 4 stations,
well under the 64 KB background memory limit; `PackService.onPack` retries
`Background.exit` without entrances/alerts if the exit-data limit is hit.
Simulator run (throwaway build with the key hard-coded, deleted afterwards): online
open stored the pack; after Settings → Connection Type → BLE → Not Connected, tapping the glance opened
the board as `45 St / Scheduled / Alert` with R rows counting down (labels were then
shortened to `by 22:01` because `home 22:01` clipped). With no fix and no cached
station the board previously stopped at "Waiting for GPS" without a request; it now
falls back to the pack first. Simulator shares storage between the test app and
sideloaded builds, so tests that expect "Waiting for GPS" must clear `pack`.
The simulator cannot open app settings for monkeydo builds here ("No settings file").

## Physical-watch verification — 2026-09-20

User installed the entrance build on a physical FR965 and reports it works
relatively well. This supersedes the "not installed on physical watch" notes in
the 2026-09-13 sections below. The watch test suite runs 11 tests, all passing
(source has 18 `(:test)` annotations; seven mark helper/probe classes). The
proxy still has 31 deterministic tests, re-run and passing after the entrance
change. The Garmin listing is now version 0.4, published and
installed on the physical FR965 (see the 2026-09-20 v0.4 upload section below).

## Glance Out Of Memory crash — 2026-09-27

Watch log `GARMIN/Apps/LOGS/CIQ_LOG.BAK` (copied over MTP): two "Out Of Memory
Error, Failed invoking <symbol>" entries, 2026-09-25 00:55 and 00:59 UTC,
Store-Version 4. PCs 0x1000133b, 0x10001061, 0x100012b6, 0x100017bc, 0x10000f6d map
(release build of `bd294a3`, `functionEntry` ranges in the debug XML) to
GlanceSelection.newest, BoardStore.forStation, BoardStore.loadAll,
MtaGlanceView.onUpdate and BoardStore.saveStation: glance code walking the
per-station board cache. The glance heap is ~60 KB with ~21 KB used at rest
(simulator status bar); a live 5-station board response near home is 1.2-2.1 KB
JSON per station, so the 8-board cache is ~12.5 KB JSON and several times that
as Monkey C objects, loaded alongside the fresh response. Fix: the glance
stores only the primary board (`BoardStore.savePrimary`); the full app still
maintains the cache. A simulator repro of the v0.4 build was attempted but the
app hung on the launch screen; not reproduced. The installed-app version is
in `GARMIN/GarminDevice.xml` (`<App>` entry, `<Version>` = internal number).
`pgrep -f MonkeyDoDeux` inside a compound shell command matches the shell
itself; kill simulator processes with `pgrep -x`.

## Connect IQ upload — 2026-09-27 (v0.6)

Signed `build/NycMta.iq` (36 KB; listing 47 KB), SHA-256
`b235ccd3fa8779e3121d09426e996730d2b01251cd8ba157e6ab32f0d6587dea`, same
dashboard workflow as v0.5. Garmin verified package and signature; listing
reads Version 0.6 (Internal: 6). What's New (verbatim): "Run packs offline: the
board now shows the pack station closest to you at any distance, with the
direction arrow and walking time, plus scheduled trains home counting down in
minutes." Simulator evidence before upload: offline at 40.660,-73.968 the board
showed Parkside Av, arrow + ~13 min, Q rows 2m/14m/24m/42m. The Set Position
dialog is under the simulator's Settings menu; relaunch the app after setting it.

## Connect IQ upload — 2026-09-26 (v0.5)

Signed `build/NycMta.iq` (35 KB; listing size 46 KB), SHA-256
`6b1430625a3c82a89216a510e6f15473a0d2bbd90bccdc7a5cc42207a4a6f29e`, uploaded
via the developer dashboard in the user's Chrome (user signed in; Chrome file
upload only accepts files under the session folder, so the .iq was copied to
`~/code/Browser/tmp-upload/` and removed afterwards). Garmin verified package
and signature; listing reads Version 0.5 (Internal: 5), BETA, App pending, and
now lists the Background Activity permission. What's New (verbatim): "Adds run
packs for running without your phone: set a Run pack key and the app downloads
scheduled trains home in the background. With no phone connection, the board
and glance count down those trains ("Sched home", "by H:MM" door time) at your
destination or at stations along the route." Install on the FR965 not yet
confirmed.

## Connect IQ upload — 2026-09-20 (v0.4)

Signed `build/NycMta.iq` (33,385 bytes; listing size 43 KB), SHA-256
`f38185863ddc8f1c4b4295e3d8cff05a15b330267b843a0489c41296e55857f3`, uploaded
to the Garmin developer dashboard and read back as Version 0.4 (Internal: 4),
status Pending, BETA. User confirms it is installed on the physical FR965.
Published What's New (verbatim): "Adds MTA service alerts: an Alert tag on the
board, a Service alerts list in the Stations menu with a scrollable detail
view, and a glance indicator. Also adds a Distance setting (walking time by
default, plus meters/feet/miles), Now for sub-minute arrivals, UP/DOWN to cycle
recent commutes, a faster refresh when a train is close, an optional train
buzz, and offline per-station boards." The published notes do not mention the
entrance arrow / walking-time distance added after the 0.3 upload. Listing
Latest Release still displays September 11, 2026 (known stale field).

## Walking-time grid detour — 2026-09-20

Walking-time estimates treated straight-line distance at 1.35 m/s (~4.9 km/h),
which reads optimistic on NYC's right-angle grid. `MtaFormat.distanceText` now
multiplies by `GRID_DETOUR = 1.3` (average Manhattan grid detour: L1/Euclidean
is ~1.27, plus a small allowance for crossings) before converting to minutes;
the Meters/Feet/Miles units remain raw straight-line. Examples: 81 m 1->2 min,
200 m 3->4 min, 368 m (Barclays -> Fulton St G) 5->6 min, 800 m 10->13 min.
`MtaFormatTest.distanceFormatRules` was updated and a 368 m grid case added; all
distance assertions pass host-side; production and test builds compile. Simulator
suite not rerun (a dev simulator session was already active). Constant is a
single knob in `source/MtaFormat.mc` if the estimate needs retuning.

## Offline multi-station cache — 2026-09-20

`BoardStore` gained a `boards` key holding up to eight per-station entries,
newest first, with the v1 `board` primary kept for the glance and used as a
lazy-migration fallback. Every station in a multi-station response is cached, so
switching to a recent station offline renders its cached board marked Cached
instead of failing; recent-commute rows show `cached <age>`. New
`BoardStoreTest.mc` covers ordering, cap, lookup and the migration fallback.
Watch suite: 16 tests, all passing. Production build succeeds.

## Controls polish — 2026-09-20

UP/DOWN now cycle saved recent commutes without opening the menu (new
`BoardView.select` path that cancels an in-flight request; `cycleRecent` wraps
and picks the first/last when nothing is selected). Automatic refresh drops to
30s while the soonest cached arrival is within five minutes. An optional Train
buzz setting (Off/2 min/5 min) vibrates once per imminent train, tracked by a
route+arrival key so it does not repeat. `MtaFormat.soonestSeconds/nextArrival`
and `Config.vibrateLead` are unit-tested. Watch suite: 15 tests, all passing.
Buzz behavior on hardware is unverified (simulator vibration is not meaningful).
Production build succeeds.

## Service alerts — 2026-09-20

Board meta adds `/ Alert` when the cached station has alerts; the Stations menu
gains `Service alerts (N)`; the glance prefixes `!`; each alert opens `AlertView`
with word-wrapped text and UP/DOWN or tap paging (page counter shown). New
`MtaFormat.wrap/words` are unit-tested (word splitting); `Config.alerts` filters
malformed entries. Watch suite: 14 tests, all passing.

Proxy side (repo `mta-proxy`): `alerts.py` parses the public
`camsys/subway-alerts` GTFS-RT feed, filters active periods, strips markup and
maps alerts to a station by route and stop ID. The board attaches
`station.alerts = [{title, desc, routes}]` and returns `alerts_available`;
alerts failures never fail the board. 35 proxy tests pass (8 new). Verified
against the live feed: 28 active alerts, Union Sq 7 hits, Lorimer St 1 hit.

Deployment happened after this watch work: the proxy was deployed on
2026-09-20 (release `20260920T160447-5b6db79`), so the live board now returns
`station.alerts`. The watch-side alert UI shipped in the 0.4 upload
(2026-09-20); see the v0.4 section above.

## Distance units, Now label and simulator workflow — 2026-09-20

Added a Distance setting (Walking time default, plus Meters/Feet/Miles) applied
to the board entrance label and station-menu subtitles; predictions within 45
seconds read "Now"; the entrance label is centered when no heading is available.
New `MtaFormatTest.mc` covers unit formatting, walking-time rounding and the Now
threshold. Watch suite: 13 tests, all passing (MonkeyDo reports PASSED; its
process still exits 1). Production and signed export builds pass.

Also fixed test hygiene: `StationCompassTest` saved a "Test" board without
restoring it, which leaked into the simulator's persisted app storage and made
subsequent app launches open that stale station. It now saves/restores the
`board` key like `LocationTest`.

Simulator workflow used on this laptop (no focus theft from the desktop):
1. Run the SDK simulator on a nested display: `Xephyr :9 -screen 1280x1400 -ac`
   then `DISPLAY=:9 ~/bin/garmin-simulator` (the wrapper adds the WebKit compat
   libs). Screenshots come from `DISPLAY=:9 import -window root out.png`.
2. Keep exactly one simulator running. If a stale instance holds TCP 1234 the
   new one binds 1235 and `monkeydo` hangs silently waiting on 1234, so kill
   simulators and wait for the port to free before starting.
3. On the simulator's Simulation menu, uncheck "App Lock Enabled" (it defaults
   on each boot); otherwise apps never come to the foreground.
4. Build tests with `monkeyc -t ... -o build/Tests.prg` and run
   `DISPLAY=:9 monkeydo build/Tests.prg fr965 -t`.
5. On the watch face press START to bring the running app forward; the app's
   board then shows. `File -> Reset All App Data` clears the app's persisted
   storage when a stale board is cached (the simulator keeps it under
   `/tmp/com.garmin.connectiq/GARMIN/APPS/DATA/`).

## Private beta invite — plan (pending, 2026-09-20)

Goal: share the app with a friend on a different Garmin watch via the existing
private beta listing, so they get a store install with the settings UI and
updates (no USB). Blocked on the friend's exact watch model and Garmin account
email.

Steps once known:
1. Confirm the watch runs Connect IQ 4.0+ (`minSdkVersion 4.0.0`); a CIQ 3.x
   device needs the min SDK lowered and glance/compass behavior retested.
2. Install that device profile in the Connect IQ SDK Manager (only fr965,
   fenix7xpro and legacy devices are local today).
3. Add `<iq:product id="..."/>` for the watch in `manifest.xml`.
4. Build the signed package: `monkeyc -e -f monkey.jungle -o build/NycMta.iq -y
   ~/.garmin/developer_key.der`; simulator smoke-test that screen shape.
5. In the Garmin developer dashboard, upload as version 0.4 with the entrance
   arrow/distance release notes, then add the friend's email as a beta tester.
6. Friend installs from the store link via the Connect IQ app.

No compass on their watch leaves distance visible without the arrow; no glance
support just hides the glance.

## Heading arrow layout — 2026-09-13

MtaBoardRenderer draws the arrow at w/2, h*0.12, with a 30-pixel shaft and proportionally enlarged arrowhead. Rotation and visibility behavior are unchanged. Agent-tested: FR965 production compilation and git diff --check pass. SDK display metadata confirms a 454 by 454 round screen; arrow geometry fits within the top region at all rotations. Simulator visual inspection passed for all eight compass directions and null-heading visibility using a temporary fixture outside the repository. All 10 simulator tests passed (0 failures/errors; MonkeyDo exits 1 despite PASSED). Contact sheet: /tmp/mta-arrow-sim-contact.png. Physical-watch installation was not performed at that time (see 2026-09-20 verification above). Rollback: restore the prior arrow coordinates and dimensions in source/MtaBoardRenderer.mc.

## Connect IQ upload — 2026-09-13

Signed build/NycMta.iq rebuilt successfully with export flag -e. SHA-256: 3e3c0238dd3732f099ae4c68f0f984a3f83d92c7aa70b6d11be95bde795b6736. Garmin sign-in cleared and user confirmed submission/agreement acceptance. Package and signature verified by Garmin; submitted version 0.3 with centered/enlarged arrow release notes. Listing https://apps.garmin.com/apps/0d372a47-1cd0-4f47-a826-b1230498bf3b now shows Version 0.3 (Internal: 3) and the new notes. It remains private BETA / App pending; displayed Latest Release still says September 11, 2026, so version/internal number and notes are the upload evidence. Not installed on physical watch at that time (see 2026-09-20 verification above).

## Nearest entrance — 2026-09-13

Proxy station.entrances is cached unchanged by BoardStore. StationCompass chooses the nearest valid coordinate locally; BoardView independently applies existing five-minute GPS and three-second heading validity. Missing entrances retain station bearing without distance; missing heading retains distance. No train-direction filtering, ranking or GPS-policy changes. Straight-line distances do not establish live entrance availability or platform access.

Agent-tested: watch simulator tests (11 in that run; 18 `(:test)` functions in source as of 2026-09-20), including nearest selection and old/new cache compatibility, pass; 31 proxy tests and public smoke/API checks pass. Eight heading renderings, missing heading, invalid-location display and no-entrance fallback were visually inspected with a temporary fixture. User requested no five-digit handling and stopped further simulator runs; final standard numeric label was compiled but not visually rechecked. Special font experiment removed. Production .prg and signed build/NycMta.iq built successfully. GitHub synchronized at `076ea29`; no Garmin upload at that time (physical install since confirmed, 2026-09-20). Current entrance package SHA-256: `a997c5e217290b1f43c26b032afd3962a38c7d494ea55a77b9fe6cacef6ef784`. Simulator stopped at user request; do not rerun for this completed task. Proxy deployment and rollback evidence: /home/d/code/mta-proxy/FINDINGS.md; source comparison: /home/d/code/mta-proxy/data/README.md.


## Release handoff reconciliation — 2026-10-03
- Approved documentation cleanup separates recorded published v0.7 (commit `211f658`), recorded installed v0.6 (GarminDevice.xml Version 6 evidence), and unpublished/uncommitted v0.8 offline-stations WIP. Corrected the stale v0.6 listing/v0.4 installation summary.
- Earlier evidence, generated assets, builds and source WIP preserved. No simulator, watch connection, build, publication or push; no new live release/install claim.

## Connect IQ private beta submission — 2026-10-03 (v0.8)
- Resumed the approved Nearby/offline-stations release. User confirmed “Approve agreement and publish v0.8” at the agreement/submission step. The earlier form tab remained reserved by its prior browser session, so a separate background tab was used; no interaction with the reserved tab.
- Reused the Oct 2 QA: 21 passing watch tests and the offline simulator UP/DOWN check. No simulator/build rerun. `build/NycMta.iq` is 54,658 bytes, SHA-256 `1e350b7ef8b49e48070c5c0c20d5499e82eb69d889d06e533dcaa2a80b3a5978`; all production inputs predate the signed package. `.prg` SHA-256 still matches `821b57bb7e75dbe46e32a3e67f634759f2377bbf14b5eb330a1cdba7e9d8982f`.
- Garmin upload showed Status: Verified, Signature: Verified, Version: 0.8 and FR965 compatibility. Filled the approved What's New text, submitted the details, and read back https://apps.garmin.com/apps/0d372a47-1cd0-4f47-a826-b1230498bf3b: Version 0.8 (Internal: 8), 93 KB, BETA / App pending. The owner-only beta notice remains; this is not evidence of a public release. Latest Release still displays September 11, 2026, so version/internal number and new notes are the authoritative submission evidence.
- What's New (verbatim): “Nearby startup with UP/DOWN browsing through the five nearest stations. Bundled offline stations show entrances, walking times, and direct lines home without a phone. GPS keeps updating while browsing; fixes station mix-ups between nearby stations with the same name.”
- Evidence: `/tmp/mta-beta-resume/garmin-v08-ready.jpg` (approved form), `garmin-v08-published.jpg` (BETA/owner-only notice), `garmin-v08-version.jpg` (visible version/internal number and notes), `garmin-v08-listing.txt` (DOM readback). Full-page capture timed out once; viewport captures succeeded.
- No watch detected in the live MTP inventory, no installation or field test. Last recorded hardware version remains 6. Source/assets and existing edits preserved; this turn updates STATUS.md and FINDINGS.md only, without commit/push. Next: install/sync v0.8, confirm installed version, then test native Run continuity and GPS/offline browsing without the phone.

## v0.8 USB sideload transfer — 2026-10-03
- User selected “USB sideload” in the native questionnaire. Live USB/MTP device detected; GarminDevice.xml Model identifies Forerunner 965, SoftwareVersion 2905 (29.05).
- `gio copy` placed `build/NycMta.prg` in the watch's `Internal Storage/GARMIN/Apps/NycMta.prg`. Read back with `gio copy` to `/tmp/mta-beta-resume/NycMta-usb-readback.prg`; SHA-256 `821b57bb7e75dbe46e32a3e67f634759f2377bbf14b5eb330a1cdba7e9d8982f` matches the build, `cmp` reports no differences, and destination size is 219,068 bytes.
- Safely unmounted the watch with `gio mount -u`; subsequent mount inventory has the Garmin volume but no Garmin mount. The masked GPhoto2/Afc/Goa-monitor notices were unrelated; MTP transfer and unmount succeeded.
- This verifies the transferred executable, not app startup or native Run behaviour after USB disconnect, nor a store-version metadata change. User launch/Nearby/UP/DOWN check and the short phone-free Run remain pending. No build/test rerun or source change; handoff updated.
- User chose “Check later” for the unplug/open/Nearby/UP/DOWN observation; launch and Run checks are explicitly deferred, with no user-observed runtime result claimed.

## User watch observation: 3 Av “No trains” — 2026-10-03
- User subsequently reported the watch shows 3 Av / “No trains” and selected “Nearby or live” as its status. This establishes a user-observed board launch, not UP/DOWN operation, store-version metadata or native Run/GPS continuity.
- Checked public L05 board at 2026-10-03 13:56 UTC (09:56 ET): station 3 Av, route L, arrivals=[], failed_feeds=[], partial=false, alerts_available=true. Active MTA alert: “No L between Lorimer St, Brooklyn and 8 Av, Manhattan”; communications upgrades and track work. The empty board matches the suspension covering 3 Av.
- Raw response and timestamp: `/tmp/mta-beta-resume/3-av-live-board.json`. Request used the public station point, not personal GPS: `/mta/board?lat=40.73285&lon=-73.98612&station=L05&limitStations=5&limitArrivals=8`. Alert source is MTA's public subway-alerts feed (`alerts.py`); the watch exposes it through START → Service alerts (`CommuteMenus.mc`). No source/build change or test rerun needed.

## Stations menu simplification — 2026-10-03
- User approved the proposed merged menu with “y”: Nearby stations, Recent commutes, Service alerts only when present, and Follow location only with a fixed manual selection. Separate Offline stations entry removed; Nearby now combines the existing offline list's entrance walking time/home hints with preserved live destination options. All trains chooses the station without route/direction filtering; explicit direction choices retain friendly labels from live destinations or bundled platform metadata.
- Changed `source/CommuteMenus.mc`, added `source/CommuteMenusTest.mc`, updated README and current handoff. Archived the previous full status in `docs/status/2026-10-03-v08.md`. Bundled coverage, main-board UP/DOWN, GPS policy, cache/run packs and prior WIP preserved.
- FR965 production/test/signed export builds pass. All 22 watch tests pass, zero failures/errors; new `combinedNearbyMenu` exercises real SDK menu items/delegate selection for offline/live direction labels, canonical station identity, All trains, conditional alerts/Follow location and the no-position empty state. MonkeyDo exits 1 despite `PASSED (passed=22, failed=0, errors=0)`; the runner validates the printed summary. Test log: `/tmp/mta-menu-qa/tests.log`.
- QA used the official SDK simulator on private Xvfb :20, under `batch` at one CPU; no desktop focus/input. SDK `monkeyc` hardcodes a 1 GB initial heap, so the same compiler main class was invoked directly with `-Xms64m -Xmx512m -XX:ActiveProcessorCount=1`. Load/memory checks remained within shared limits. Task-owned simulator and Xvfb terminated; only the personal X0 socket remains. No new visual menu capture or physical-menu check.
- Candidate `build/NycMta-menu.prg`: 218,748 bytes, SHA-256 `339587874e4f1dc284e6bbe1daeb6d6ae229c3ee5d2ed3588893f166f5788b2d`. Signed `build/NycMta-menu.iq`: 54,657 bytes, SHA-256 `3bfec1f1903821c570f32ae09c684a8381291ca0932b90bbcbe3f62fe4cc7747`. Original published/transferred v0.8 artifacts retained unchanged.
- No FR965 connected in the live MTP inventory; new menu candidate not installed/published. USB timing questionnaire returned no answer, so no deferral or installation claim inferred. Candidate and handoff are ready for the already-selected sideload route when the watch is reconnected. No commit/push.

## Simplified menu USB sideload — 2026-10-03, 10:40 ET
- User selected “sideload no unmount” in the native questionnaire. This authorizes the menu candidate transfer and overrides the earlier automatic unmount step for this operation.
- Live USB/MTP inventory identifies Garmin `091e:50db`; `GarminDevice.xml` confirms Forerunner 965, firmware 29.05. Copied `build/NycMta-menu.prg` to `Internal Storage/GARMIN/Apps/NycMta.prg` with `gio copy`.
- Read back to `/tmp/mta-beta-resume/NycMta-menu-usb-readback.prg`: SHA-256 `339587874e4f1dc284e6bbe1daeb6d6ae229c3ee5d2ed3588893f166f5788b2d` matches the source, `cmp` exits 0 and destination size is 218,748 bytes. Original v0.8 readback evidence is retained separately.
- No unmount/eject command issued. After-transfer inventory still shows the Garmin mount at `mtp://091e_50db_0000d793efa7/`. Transfer/readback is verified; app startup, physical menu behaviour and native Run/GPS/offline field checks remain pending. No store upload, build/test rerun or commit/push.

## Project save — 2026-10-03
- User requested `ss`, authorizing the shared save/commit/push workflow for this project's pending work. Save scope includes Nearby/offline/menu source and tests, generated station resources, the generator and pinned Stations.csv input, simulator screenshots and documentation; local build artifacts remain ignored. Earlier release and transfer statements above describe their respective actions, not the current Git state.
- Confirmed the existing watch test log ends with `PASSED (passed=22, failed=0, errors=0)`, and all current source/resource/manifest/build-config inputs predate the tested menu artifact. No duplicate simulator/build run.
- Ran `tools/build_stations.py --check` under `batch` with one-thread library limits: `up to date: 229 stations`. Generator Python syntax and `git diff --check` pass. Load remained below shared limits. Fetched origin successfully; local and remote main were aligned at the `211f658` baseline before saving.
- Current objective, verified transfer, no-unmount instruction, offline coverage and pending physical menu/Run checks are recorded in STATUS.md. Store publication of the menu candidate remains a separate action requiring authorization.

## Questionnaire timeout and final handoff save — 2026-10-03
- User requested a longer questionnaire wait, settling on 55 minutes, then `ss`.
  The change belongs to `/home/d/system-setup`: implementation `34d5448` is verified
  on its remote main. Its managed Codex launcher sets a 3,300-second Default-mode
  deadline; eight focused tests pass, and a synthetic native popup in an isolated
  real TUI remained open beyond 130 seconds without an automatic answer. No model
  request was made. Full 55-minute wall-clock verification remains unperformed.
- Existing shells/views require `source ~/.bash_aliases` and reopening Codex to
  load the launcher. Detailed objective, evidence, limits and recovery are in
  `/home/d/system-setup/agents/codex-question-timeout/STATUS.md` and `FINDINGS.md`.
- This save verified MTA implementation `c53fc0c` on remote main and found its
  working tree clean before the two handoff edits. Watch source/artifacts were
  unchanged, so completed build/test and transfer evidence was reused.
- No physical-menu/UP/DOWN/Run/GPS result arrived, no watch operation/unmount was
  issued, and no menu package was published. Existing pending field checks and
  the user's explicit no-unmount preference remain in the current status.
