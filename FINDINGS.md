# Findings

## v0.7 polish: glance nearest station, storage reads, clipping — 2026-09-27
- `Position.getInfo()` works in the glance scope; the simulator's Set Position feeds it. The glance uses it to pick the nearest pack station.
- The glance previously re-read the board (several times) and the pack from Storage on every 5 s redraw. Each read copies the whole value into the 60 KB glance heap. It now caches both per show. Simulator glance memory offline with a pack: 31.3/59.8 KB.
- The board read `BoardStore.load()` every second (refreshDelay, maybeBuzz, meta age) and `PackStore.ageSeconds()` (the whole pack) every second when scheduled. It now uses in-memory `_boardArrivals`/`_boardTime`.
- FR965 FONT_GLANCE fits about 10 characters beside the route badge. The glance primary line reads "7m Fort Ha..." and the second line "Home by 7:46" (fits).
- Board meta line: the chord at y=0.31h is about 420 px, so it now clips at w-70 (was w-120).
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
