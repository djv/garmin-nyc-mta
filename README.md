# NYC MTA (Garmin fr965)

Nearby station with four arrivals. No default location: without usable GPS,
the last cached station is refreshed by ID and marked “Last station.”

UI: MTA-colored circular route bullets; explicit 6X/7X/FX route IDs draw diamonds
with the base route label. Ordinary express routes are not automatically diamonds.
Colors follow https://www.mta.info/document/168976 and the bundled MTA routes.txt.
Badges are also used in the glance. Destinations are white; times have their own
right-aligned column. Saved GPS describes location reuse, separate from data age.

## Hosted proxy

`https://ubuntu-8gb-nbg1-1.tailca4726.ts.net`

Runs persistently on Hetzner through Tailscale Funnel. No laptop proxy or tunnel
is required. Endpoints: `GET /mta/health`, `GET /mta/board?lat&lon&limitStations=1&limitArrivals=4`.

## Build

```bash
monkeyc -d fr965 -f monkey.jungle -o build/NycMta.prg -y ~/.garmin/developer_key.der
```

## Sideload

USB → copy `build/NycMta.prg` to `GARMIN/APPS/`.

## Settings (Connect Mobile → watch → NYC MTA)

- Proxy URL defaults to `https://ubuntu-8gb-nbg1-1.tailca4726.ts.net` (without `/mta`).
  The app appends the API path. The exact old bundled Cloudflare URL is migrated
  and saved automatically; other custom settings are preserved. Custom servers
  require HTTPS with a trusted certificate. MTA upstream outages remain possible.
- Distance defaults to Walking time (`~3 min walk`); the estimate walks the
  straight-line distance at ~4.9 km/h and applies a 1.3x street-grid detour so
  it is not optimistic in gridded Manhattan. Switch to Meters, Feet or Miles for
  the raw straight-line distance. Applies to the board label and station menus.
- Train buzz is Off by default; 2 or 5 minutes before the next cached arrival
  the watch vibrates once. It only fires while the board is visible.

## Run pack (offline scheduled trains home)

For run-one-way-then-ride-home runs without the phone. `~/code/Browser/run-routes/run_route.py
send` of a one-way route posts the destination station plus up to three bail-out stations
to the proxy (`POST /mta/pack`) under a private key. Enter that key once in
Connect Mobile → NYC MTA → **Run pack key**. The app then fetches `GET /mta/pack` on open
(at most every 10 min) and a background service refreshes it every 15 min while the
phone is connected. The pack holds up to 30 scheduled departures per station for the
next 4 hours that reach a station near home (one-seat rides, planned work included),
with minutes to the door, entrances and alert titles; it expires after 36 h.

When a live request fails (no phone), a nearby choice uses only the matching pack
station ID. If that station is absent or its departures have passed, it shows the
cached trains or bundled station information instead. With no nearby list or explicit
selection, the pack falls back to the nearest pack station (any distance), then the
run's destination without a usable fix:
`Sched home` in the header, rows as route bullet, `by 22:01` (door arrival) and a
countdown. The glance shows the destination's next scheduled train when offline or
when nothing else is cached. Scheduled times can be a few minutes off real trains.

## Offline stations (bundled, no phone, no key)

The app ships a fixed dataset of every subway station within 10 km of home
(34 E 11th St; 229 stations from 258 MTA platforms, 1,236 entrances), built by
`tools/build_stations.py` into `resources/stations/` (see `meta.json` for sources,
dates and SHA-256). Per station: name, lines, platform direction labels from MTA
Stations.csv ("Uptown" / "Downtown", "Manhattan" / "Outbound"...), entry-allowed
entrances, and the lines that ride home without a change ("Home: 4 5 Uptown"),
precomputed from GTFS stop order: a line counts in a direction when at least half of
its 06-21 h trips from that platform later stop within 700 m of home (same rule as
the proxy's home stations). No schedules.

When a live request fails, the board falls back in this order: fresh run pack (it has
times) > cached board for the requested station with trains still to come > the shown
board while it has trains and is within 1 km > the bundled station nearest the GPS fix
(or the watch's last known position, <15 min; the selected station when one is
selected). The offline board shows the entrance arrow and walk time, the ride home in
the meta line, one row per line group and direction (rides home first, in green) and
`Offline map` at the bottom. Stations → **Nearby stations** lists the five nearest with
walk time and ride home, using the same bundled data with or without the phone;
choose **All trains** or a line/direction to select one. Offline with no trains left on its
cached board, the glance shows the nearest bundled station and its ride home. The
glance loads only the 3.9 KB coordinate index and one 16-station chunk.

Regenerate after new MTA data: `python3 tools/build_stations.py` (`--check` verifies
the checked-in output; inputs: `tools/data/Stations.csv`, mta-proxy's
`google_transit.zip` and `data/entrances-2024.json`).

## Controls

The app opens in Nearby mode, showing the nearest bundled station when a recent
watch position is available. DOWN advances through the five nearest station complexes;
UP goes back, and both wrap. This works without a phone or saved commutes, clears any
line/direction filter, and continues checking GPS every 120s while visible. Moving
beyond the current five stations resets browsing to the new nearest station.
Tap refreshes location and arrivals; START opens Stations, including Recent commutes.
Explicit menu selections remain fixed. Arrivals refresh every 60s, or every 30s while
a train is within five minutes. Without a position, a cached board is labelled Last station.
Nearby uses the bundled official station complexes and entrances to avoid including
another avenue's same-name station. Removed live rows are marked Partial; the proxy's
eight-row limit can still omit valid trains before filtering.
GPS fixes must have valid coordinates and be between zero and five minutes old;
reused fixes are marked Saved GPS, independently of arrival age.
A valid cached watch fix is used immediately, without waiting
for GPS. After its arrival request completes, fresh GPS is acquired and arrivals
are refreshed again; requests remain serialized. No phone location is used.
No usable GPS means no distances. With no cached station, Waiting for GPS offers tap to retry
or START for recent commutes. GPS wait is 9–15s; total request
watchdog is 25s. Failed refreshes preserve old rows marked Offline with their age,
or, when selecting another station, show that station's cached board marked
Cached. The five nearby stations from each automatic query are cached separately
(up to eight stations) so they can be browsed underground.
Arrival timestamps count down on repaint; passed predictions are hidden, and
predictions within 45 seconds read Now. Eight
predictions are cached to refill the four visible rows between refreshes.
Partial data is marked when a station's feeds are unavailable.

An empty glance shows Open app and makes no requests. A populated glance
refreshes its cached station by ID without GPS.
# Station picker and recent commutes

The glance uses the most recently used saved selection matching its cached
station, including that selection's line and direction on refresh. With no
matching recent selection, it shows the next arrival across lines/directions.
Glance refresh never changes recency. The board's top-center arrow points toward
the nearest entry-allowed entrance of the displayed station, relative to the top of the watch face. The approximate straight-line distance appears beside it using the Distance setting (walking time by default); when no heading is available the label is centered without the arrow. Selection uses distance only, independent of train direction. Entrance data does not establish live availability or access to the selected platform. If entrances are unavailable, the arrow targets the station point without a distance. Hold the watch level
to read it. Compass events run only while the board is visible. Missing heading
(or no event for three seconds), missing/expired GPS, or coincident coordinates
hide the arrow. Missing/expired GPS also hides the entrance distance; missing heading leaves the distance visible. This is a straight-line bearing, not walking directions.

Glance: while visible, checks every five seconds and refreshes arrivals once
the cached data reaches one minute old. Requests time out after 15 seconds;
failures retry after 30 seconds and retain the previous cache with an Offline
indicator. Hiding the glance stops polling and invalidates pending callbacks.
This is foreground refresh only, not a background service while the glance is hidden.

Press START/select (or hold UP/menu) on the board to open Stations. Tapping
the board still refreshes. Choose Nearby stations, a line, then one of its
two GTFS travel directions. Destination names label the directions; short-turn
trains in the same direction remain included. All lines shows the whole station.
Board and recent-commute labels use destinations (for example, `L to Canarsie`)
instead of N/S bound. The two direction choices use shortened, deduplicated
terminal names. Labels are saved with recents and updated from fresh station
options without changing recency. Without new predictions, saved labels remain;
older entries without a label show `Direction N/S` until refreshed. Direction
IDs and train filtering are unchanged.
BACK cancels the picker and returns to the board.
When the proxy reports active service alerts for the displayed station's lines,
the board meta adds `/ Alert`, the glance prefix shows `!`, and the Stations menu
gains `Service alerts (N)`. Each alert opens a scrollable detail view (tap or
DOWN for the next page, UP for the previous). Alert text is supplied by the MTA
feed; the proxy strips markup and clips nothing on the watch, so long alerts page.
Nearby and recent station rows show all served routes as MTA-colored bullets,
including diamond variants. Badges wrap after seven routes; station names and
distance/selection details remain above them. Routes describe station service,
not a guarantee that each line currently has predictions.

Selections are automatically kept as the 10 most recently used station/line/
direction combinations. Reuse moves an entry to the newest position; an 11th
unique selection evicts the least recently used. No favorites. The displayed
list is distance-sorted when a location no more than five minutes old is
available, otherwise most-recent-first. Entries with a cached board show
`cached <age>`. Distances are approximate straight-line
distances to GTFS station points, not walking routes or entrance distances.
Walking-time estimates apply the 1.3x grid detour to that straight-line
distance; the Meters/Feet/Miles units stay raw straight-line.
Station coordinates never serve as the user’s location.

The Stations menu has **Nearby stations**, **Recent commutes**, **Service alerts**
when alerts exist, and **Follow location** only while a manual selection is active.
There is one Nearby list for both live and offline use. Its walking estimate targets
the nearest entrance, and the green note shows the usual direct ride home.
Line/direction choices use live destinations when available and bundled platform
direction labels otherwise.

Follow location clears the filter and reacquires location. A selected station
stays selected during refresh; background refresh does not change recency.
Nearby entries are recomputed from the five nearest bundled station complexes,
retaining any live destination labels already fetched for them.

Requires the matching proxy update: optional `station`, `route`, and `dir=N|S`
board parameters, with filtering before the arrival limit, plus per-station
`options` containing route, direction and destination labels.
