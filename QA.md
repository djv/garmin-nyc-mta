# Hetzner hosting verification — 2026-09-10 (America/New_York)

Public base: `https://ubuntu-8gb-nbg1-1.tailca4726.ts.net`.
Deployment uses `/home/dev/mta-proxy/current`, Python 3.12, a fully pinned venv,
and 496 bundled station records. No static ZIP parsing is needed on the server.

- 12 proxy tests pass, including preserved HTTP 503 response, partial feed
  behavior, configurable binding, health failure classification and GPS-free logs.
- Public health, Lorimer nearby lookup, merged Union Square, station-ID lookup,
  N/S route filtering and 400/404 error bodies pass. Existing five smoke checks pass.
- Eight simultaneous requests immediately after process restart (empty feed
  cache) all succeed in 0.988–2.120 seconds, below the watch's ten-second timeout.
- SIGKILL to only mta-proxy's MainPID changes PID and NRestarts from 0 to 1;
  service returns active after the configured three-second delay.
- Listener is 127.0.0.1:8087. Proxy and five-minute health timer are enabled;
  timer active, dev Linger=yes, tailscaled enabled. No shared-server reboot.
- Before/after Funnel JSON matches exactly after removing only the added /mta
  handler on 443. Existing 8443 and HN/Sofia handlers remain unchanged.
- Sofia public nearby API returns 200 and real stop data. HN public API returns
  the same 401 {"error":"No session"} as its local pre-change baseline; authenticated
  HN content was not exercised. This verifies routing and unchanged auth behavior.
- Journald contains method/path/status/timing without lat/lon queries. The health
  service logs healthy station=L03; upstream failures have their own classification.
- FR965 production and test builds succeed with SDK 9.1.0. Six simulator tests
  pass, including persisted legacy-URL replacement, custom URL preservation and
  existing location, glance selection and commute regressions. MonkeyDo exits 1
  despite its explicit PASSED (6 passed, 0 failed, 0 errors) summary.
- Production simulator shows a refreshing populated glance and a live Lorimer St
  board with four L arrivals through the hosted endpoint. Physical watch not installed.

- Ten-minute public soak passes: 39 requests over 600.6 seconds, no failed or
  partial responses; maximum 8.165 seconds. Most requests were under one second.
  This is a measured run, not a guarantee of future MTA or network availability.
- Leaving the populated glance visible across its refresh interval resets the
  data age and changes live arrivals.
- FR965 production SHA-256: `df5eb6053c2c37cc879f1e602aded6b47664185e5fb7576d73d18e37e0621b50`.

---

# Location reliability — 2026-09-10

FR965 production build successful with SDK 9.1.0. Five simulator test functions
pass (zero failures/errors): GPS age/quality/coordinate validation, location
lifecycle, selection filtering, and recent-commute rules. The MonkeyDo test
launcher exits 1 even when its printed test summary is PASSED.

Deterministic simulator coverage includes first launch without cache/GPS,
cache-first display, cached station ID fallback with no personal coordinates,
future/expired fixes, GPS recovery and changed coordinates, one-minute arrivals
and two-minute location scheduling, fixed selections, retained rows on timeout,
expired distance suppression, hidden callbacks, and GPS callbacks from an earlier
acquisition. Empty/invalid glance cache displays Open app; its request guard
returns before creating a network request. Existing glance line/direction tests pass.
Network calls in the location lifecycle tests are intercepted: these checks do
not establish current proxy/tunnel availability or real-world GPS performance.
No physical-watch installation was performed for this revision.

The older observations below are historical; the configured location fallback
and arrival-only automatic refresh described there have now been removed.

# Verification — 2026-09-10

Recent-selection glance update: simulator tests passed for most-recent matching
station selection, route/direction exclusion, no-match fallback, and existing
recency rules. Production build successful. Upper-right Stations arrow visually
verified on the live Lorimer board; bottom hint removed. No physical-watch test.

UI polish: blue train launcher icon rendered from versioned SVG; simulator
glance visually checked with smaller primary type and muted metadata. Live
Lorimer board checked with four rows, full Canarsie labels, wider destination
column, and START hint. Final FR965 build successful; not installed on watch.

Glance refresh fix: FR965 production and test builds compile. Left the simulator
glance visible without interaction and observed another automatic cache-age reset
and updated countdown after the one-minute refresh interval. Simulator memory
display was 11.3/59.8 kB. Timeout/late-callback guards inspected in code; physical
watch and failure-recovery paths not exercised for this revision.

Built for Forerunner 965 with Connect IQ SDK 9.1.0 and exercised in simulator 5.2.0.

Verified:

- Glance opens full board without the previous Too Many Timers crash.
- Union Square merges platform groups and displays multiple routes.
- Automatic refresh updates arrivals without clearing the board or reacquiring GPS.
- Manual refresh keeps the existing board visible while acquiring location.
- Data age ticks; timestamps drive countdowns and hide past predictions.
- Arrival times and data age precede clipped text in the glance.
- Paused proxy test: old arrivals remain visible, request times out, Offline label
  appears. Resuming the proxy and retrying restores live data.
- GPS quality Usable at 40.7140,-73.9507 selects Lorimer St, marked live, with L arrivals.
- No fresh GPS uses the configured Union Square demo fallback.
- Proxy: four deterministic regression tests plus five live smoke checks pass.

Physical-device verification:

- Sideloaded 119212-byte NycMta.prg through MTP into GARMIN/Apps.
- Read-back SHA-256 matched the project build:
  0329eb2908d642a852a4689bb738a1cc88af2864402734b8b50a35613849bee5
- User opened the app on the watch, tapped refresh, observed Refreshing followed
  by STALE and an increasing data-age counter, and confirmed correct station and
  arrival times. This is user-reported device evidence, not a captured screenshot.

Remaining field observations (not measured in this session): outdoor GPS acquisition,
long-duration battery use, and on-device glance behavior. Fresh GPS and glance
behavior were exercised in the simulator. STALE refers to saved location and is
visually easy to confuse with arrival-data age.

Optional field checklist:

1. Connect watch by USB/MTP and copy build/NycMta.prg into GARMIN/APPS.
2. Keep Garmin Connect connected on the phone. The persistent Hetzner proxy
   requires no laptop proxy/tunnel.
3. Open outdoors: verify nearest station, four arrivals and refreshed age.
4. Leave board open for a minute; confirm refresh preserves the board.
5. Return to glance: verify station, arrival time and cache age.

Simulator setup: Settings > Set Position uses decimal latitude,longitude;
Settings > Set GPS Quality must be Usable or Good for a fresh-fix test.
The long Settings menu must be scrolled to reach these controls.
# Station picker update (2026-09-10)

- Build successful for FR965; simulator recency test passed (10-item eviction,
  reuse/deduplication, distance order, no-location fallback).
- Eight deterministic proxy tests passed, including same-direction short turns
  and filtering before arrival limits.
- Simulator nearby, line and destination menus inspected during development.
- Two-direction final build loaded in simulator; physical watch not connected.
- START/menu opens picker, tap refreshes. No favorites or manual pinning.
- Distances now marked direct/approximate and hidden without usable GPS.
