# NYC MTA (Garmin fr965)

MVP: nearby station with four arrivals. Current demo fallback is Union Square;
Config.mc contains the coordinates (Lorimer is noted there).

UI: MTA-colored circular route bullets; explicit 6X/7X/FX route IDs draw diamonds
with the base route label. Ordinary express routes are not automatically diamonds.
Colors follow https://www.mta.info/document/168976 and the bundled MTA routes.txt.
Badges are also used in the glance. Destinations are white; times have their own
right-aligned column. Saved GPS describes location reuse, separate from data age.

## Proxy (laptop, required)

```bash
python3 server.py  # ~/code/mta-proxy, :8087
```

Endpoints: `GET /mta/health`, `GET /mta/board?lat&lon&limitStations=1&limitArrivals=4`

## Build

```bash
monkeyc -d fr965 -f monkey.jungle -o build/NycMta.prg -y ~/.garmin/developer_key.der
```

## Sideload

USB → copy `build/NycMta.prg` to `GARMIN/APPS/`.

## Settings (Connect Mobile → watch → NYC MTA)

- Proxy URL requires HTTPS with a trusted certificate. The current default is a
  temporary Cloudflare tunnel, available only while the tunnel and proxy run.
  After restarting the tunnel, check tunnel.log and update the setting.
  Plain LAN/Tailscale HTTP is rejected by simulator/device HTTPS policy.

## Controls

Tap / Enter / Start: refresh location and arrivals. Automatic refresh every 60s
reuses the location and keeps the board visible. Reopen or tap after moving.
No GPS → recent fix or configured fallback. GPS wait is 9–15s; total request
watchdog is 25s. Failed refreshes preserve old rows marked Offline with their age.
Arrival timestamps count down on repaint; passed predictions are hidden. Eight
predictions are cached to refill the four visible rows between refreshes.
Partial data is marked when a station's feeds are unavailable.

Glance refreshes the cached station on show if at least 120s old; it has no
background network service.
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
BACK cancels the picker and returns to the board.

Selections are automatically kept as the 10 most recently used station/line/
direction combinations. Reuse moves an entry to the newest position; an 11th
unique selection evicts the least recently used. No favorites. The displayed
list is distance-sorted when a location no more than five minutes old is
available, otherwise most-recent-first. Distances are approximate straight-line
distances to GTFS station points, not walking routes or entrance distances.
No-GPS fallback coordinates never produce displayed personal distances.

Automatic nearest clears the filter and reacquires location. A selected station
stays selected during refresh; background refresh does not change recency.
Nearby entries are from the last automatic-location query (up to five GTFS
station points, merged where applicable).

Requires the matching proxy update: optional `station`, `route`, and `dir=N|S`
board parameters, with filtering before the arrival limit, plus per-station
`options` containing route, direction and destination labels.
