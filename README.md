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

## Controls

Tap: refresh location and arrivals. Automatic arrivals refresh every 60s;
automatic-nearest mode checks GPS every 120s while visible. Explicit station
selections remain fixed. Valid cached arrivals appear immediately on opening.
GPS fixes must have valid coordinates and be between zero and five minutes old;
reused fixes are marked Saved GPS, independently of arrival age.
A valid cached watch fix is used immediately, without waiting
for GPS. After its arrival request completes, fresh GPS is acquired and arrivals
are refreshed again; requests remain serialized. No phone location is used.
No usable GPS means no distances. With no cached station, Waiting for GPS offers tap to retry
or START for recent commutes. GPS wait is 9–15s; total request
watchdog is 25s. Failed refreshes preserve old rows marked Offline with their age.
Arrival timestamps count down on repaint; passed predictions are hidden. Eight
predictions are cached to refill the four visible rows between refreshes.
Partial data is marked when a station's feeds are unavailable.

An empty glance shows Open app and makes no requests. A populated glance
refreshes its cached station by ID without GPS.
# Station picker and recent commutes

The glance uses the most recently used saved selection matching its cached
station, including that selection's line and direction on refresh. With no
matching recent selection, it shows the next arrival across lines/directions.
Glance refresh never changes recency. The board's upper-right Stations arrow
points toward the physical START button.

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
Nearby and recent station rows show all served routes as MTA-colored bullets,
including diamond variants. Badges wrap after seven routes; station names and
distance/selection details remain above them. Routes describe station service,
not a guarantee that each line currently has predictions.

Selections are automatically kept as the 10 most recently used station/line/
direction combinations. Reuse moves an entry to the newest position; an 11th
unique selection evicts the least recently used. No favorites. The displayed
list is distance-sorted when a location no more than five minutes old is
available, otherwise most-recent-first. Distances are approximate straight-line
distances to GTFS station points, not walking routes or entrance distances.
Station coordinates never serve as the user’s location.

Automatic nearest clears the filter and reacquires location. A selected station
stays selected during refresh; background refresh does not change recency.
Nearby entries are from the last automatic-location query (up to five GTFS
station points, merged where applicable).

Requires the matching proxy update: optional `station`, `route`, and `dir=N|S`
board parameters, with filtering before the arrival limit, plus per-station
`options` containing route, direction and destination labels.
