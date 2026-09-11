# Verification — 2026-09-10

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
2. Keep the laptop proxy and current HTTPS tunnel running; keep Garmin Connect
   connected on the phone. Tunnel URLs are temporary; update proxyUrl if changed.
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
