#!/usr/bin/env python3
"""Build the bundled offline station dataset for the watch (no network, no schedules).

Every subway station within RADIUS_M of home, grouped by complex and stop name:
name, point, lines, platform direction labels (MTA Stations.csv), entry-allowed
entrances (MTA 2024 entrance snapshot) and, per direction, the lines that give a
one-seat ride to a home station (stop order on MTA GTFS static trips, 06-21 h).

Inputs (pinned, see SOURCES) -> outputs (checked in, regenerate with this script):
  resources/stations/stations.xml   jsonData declarations (index + chunks glance-scoped)
  resources/stations/idx.json       [lat_e5, lon_e5, ...] per station, nearest home first
  resources/stations/cNN.json       CHUNK stations each: [id, name, lat_e5, lon_e5, groups, entrances, home]
                                    groups = [routes, north label, south label,
                                              home routes north, home routes south, ...]
                                    entrances = [dlat_e5, dlon_e5, ...] from the point
                                    home = 1 for a home station (within HOME_RADIUS_M)
  resources/stations/meta.json      sources, dates, SHA-256, counts (provenance, not bundled)
  source/StationData.mc             generated constants and the chunk resource table

Usage: tools/build_stations.py [--gtfs ZIP] [--entrances JSON] [--check]
Deterministic: same inputs give byte-identical outputs (no clock, sorted everywhere).
"""
import argparse
import collections
import csv
import hashlib
import io
import json
import math
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOME = (40.73339, -73.99367)  # 34 East 11th Street, New York
HOME_LABEL = "34 E 11th St"
RADIUS_M = 10000
HOME_RADIUS_M = 700  # same rule as mta-proxy /mta/reach and run-routes: stations this close are "home"
CHUNK = 16
DAY_FROM_S, DAY_TO_S = 6 * 3600, 21 * 3600  # trips departing in this window decide home rides
HOME_SHARE = 0.5  # a line counts when at least half of its daytime trips reach a home station

SOURCES = {
    "stations": {
        "path": ROOT / "tools/data/Stations.csv",
        "url": "https://data.ny.gov/api/views/39hk-dx4f/rows.csv?accessType=DOWNLOAD",
        "name": "MTA Subway Stations (data.ny.gov 39hk-dx4f)",
        "retrieved": "2026-09-29",
    },
    "entrances": {
        "path": Path.home() / "code/mta-proxy/data/entrances-2024.json",
        "url": "https://data.ny.gov/resource/i9wp-a4ja.json",
        "name": "MTA Subway Entrances and Exits: 2024 (data.ny.gov i9wp-a4ja)",
        "retrieved": "2026-09-13",
    },
    "gtfs": {
        "path": Path.home() / "code/mta-proxy/google_transit.zip",
        "url": "http://web.mta.info/developers/data/nyct/subway/google_transit.zip",
        "name": "MTA NYCT subway GTFS static",
        "retrieved": None,  # feed_info dates are recorded instead
    },
}

# GTFS route ids -> the bullet the watch draws (Stations.csv uses S for shuttles).
ROUTE_ALIAS = {"6X": "6", "7X": "7", "FX": "F", "GS": "S", "FS": "S", "H": "S", "SI": "SIR"}
# "Last Stop" marks a platform direction with no departing service: show nothing.
BLANK_LABELS = {"Last Stop"}


def meters(lat1, lon1, lat2, lon2):
    k = math.cos(math.radians(lat1))
    return math.hypot((lat2 - lat1) * 111320.0, (lon2 - lon1) * 111320.0 * k)


def e5(v):
    return int(round(v * 100000))


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_stations(path):
    rows = list(csv.DictReader(open(path, newline="", encoding="utf-8")))
    for r in rows:
        r["lat"] = float(r["GTFS Latitude"])
        r["lon"] = float(r["GTFS Longitude"])
        r["routes"] = r["Daytime Routes"].split()
    return rows


def label(v):
    v = (v or "").strip()
    return "" if v in BLANK_LABELS or v.lower() == "nan" else v


def home_rides(gtfs_path, home_ids):
    """(parent stop id, direction N|S) -> sorted watch routes whose daytime trips mostly reach home."""
    z = zipfile.ZipFile(gtfs_path)
    trip_route = {}
    for t in csv.DictReader(io.TextIOWrapper(z.open("trips.txt"), encoding="utf-8")):
        trip_route[t["trip_id"]] = ROUTE_ALIAS.get(t["route_id"], t["route_id"])
    stops = collections.defaultdict(list)
    for s in csv.DictReader(io.TextIOWrapper(z.open("stop_times.txt"), encoding="utf-8")):
        h, m, sec = s["departure_time"].split(":")
        stops[s["trip_id"]].append((int(s["stop_sequence"]), s["stop_id"], int(h) * 3600 + int(m) * 60 + int(sec)))
    total = collections.Counter()
    home = collections.Counter()
    for trip, seq in stops.items():
        seq.sort()
        route = trip_route.get(trip)
        if route is None:
            continue
        # Index of the last home stop on the trip: every earlier stop rides home.
        last_home = max((i for i, (_, sid, _) in enumerate(seq) if sid[:-1] in home_ids), default=-1)
        for i, (_, sid, dep) in enumerate(seq):
            if sid[-1] not in "NS" or not (DAY_FROM_S <= dep % 86400 < DAY_TO_S):
                continue
            key = (sid[:-1], sid[-1], route)
            total[key] += 1
            if i < last_home:
                home[key] += 1
    out = collections.defaultdict(set)
    for key, n in total.items():
        if home[key] >= HOME_SHARE * n:
            out[key[:2]].add(key[2])
    feed = next(csv.DictReader(io.TextIOWrapper(z.open("feed_info.txt"), encoding="utf-8")))
    return out, feed


def load_entrances(path, stop_ids):
    result = collections.defaultdict(set)
    for row in json.loads(Path(path).read_text()):
        if row.get("entry_allowed") != "YES":
            continue
        try:
            lat, lon = float(row["entrance_latitude"]), float(row["entrance_longitude"])
        except (KeyError, ValueError, TypeError):
            continue
        if not (math.isfinite(lat) and math.isfinite(lon)):
            continue
        for sid in row.get("gtfs_stop_id", "").split(";"):
            sid = sid.strip()
            if sid in stop_ids:
                result[sid].add((e5(lat), e5(lon)))
    return result


def route_order(routes):
    """Stations.csv daytime order, deduplicated."""
    return list(dict.fromkeys(routes))


def build(args):
    rows = load_stations(SOURCES["stations"]["path"])
    near = [r for r in rows if meters(*HOME, r["lat"], r["lon"]) <= RADIUS_M]
    home_ids = {r["GTFS Stop ID"] for r in rows if meters(*HOME, r["lat"], r["lon"]) <= HOME_RADIUS_M}
    rides, feed = home_rides(args.gtfs, home_ids)
    entrances = load_entrances(args.entrances, {r["GTFS Stop ID"] for r in near})

    # One offline station per complex and stop name (Times Sq-42 St and 42 St-Port Authority stay apart).
    units = collections.defaultdict(list)
    for r in near:
        units[(r["Complex ID"], r["Stop Name"])].append(r)

    stations = []
    for (_, name), members in units.items():
        # Groups with more lines first, then GTFS id, so the proxy id is the busiest platform.
        members.sort(key=lambda r: (-len(r["routes"]), r["GTFS Stop ID"]))
        lat = sum(r["lat"] for r in members) / len(members)
        lon = sum(r["lon"] for r in members) / len(members)
        plat, plon = e5(lat), e5(lon)
        groups = []
        for r in members:
            sid = r["GTFS Stop ID"]
            routes = route_order(r["routes"])
            hn = [x for x in routes if x in rides.get((sid, "N"), ())]
            hs = [x for x in routes if x in rides.get((sid, "S"), ())]
            groups += [" ".join(routes), label(r["North Direction Label"]), label(r["South Direction Label"]),
                       " ".join(hn), " ".join(hs)]
        points = sorted(set().union(*(entrances.get(r["GTFS Stop ID"], set()) for r in members)))
        flat = []
        for (a, b) in points:
            flat += [a - plat, b - plon]
        is_home = any(r["GTFS Stop ID"] in home_ids for r in members)
        stations.append({
            "id": members[0]["GTFS Stop ID"], "name": name, "lat": plat, "lon": plon,
            "groups": groups, "entrances": flat, "home": is_home,
            "dist": meters(*HOME, lat, lon),
        })
    stations.sort(key=lambda s: (round(s["dist"], 1), s["id"]))

    out_dir = ROOT / "resources/stations"
    files = {}
    idx = []
    for s in stations:
        idx += [s["lat"], s["lon"]]
    files["idx.json"] = compact(idx)
    nchunks = (len(stations) + CHUNK - 1) // CHUNK
    for k in range(nchunks):
        part = stations[k * CHUNK:(k + 1) * CHUNK]
        files["c%02d.json" % k] = compact([[s["id"], s["name"], s["lat"], s["lon"], s["groups"], s["entrances"], 1 if s["home"] else 0]
                                           for s in part])
    feed_dates = "%s..%s" % (feed["feed_start_date"], feed["feed_end_date"])
    meta = {
        "generator": "tools/build_stations.py",
        "home": [HOME[0], HOME[1]], "homeLabel": HOME_LABEL, "radiusM": RADIUS_M, "homeRadiusM": HOME_RADIUS_M,
        "stations": len(stations), "platforms": len(near), "entrances": sum(len(s["entrances"]) // 2 for s in stations),
        "homeStations": sorted({s["name"] for s in stations if s["home"]}),
        "sources": {
            "stations": {"name": SOURCES["stations"]["name"], "url": SOURCES["stations"]["url"],
                         "retrieved": SOURCES["stations"]["retrieved"], "sha256": sha256(SOURCES["stations"]["path"])},
            "entrances": {"name": SOURCES["entrances"]["name"], "url": SOURCES["entrances"]["url"],
                          "retrieved": SOURCES["entrances"]["retrieved"], "sha256": sha256(args.entrances)},
            "gtfs": {"name": SOURCES["gtfs"]["name"], "url": SOURCES["gtfs"]["url"], "feed": feed_dates,
                     "version": feed["feed_version"], "sha256": sha256(args.gtfs)},
        },
        "homeRule": "per platform direction, lines whose %02d:00-%02d:00 trips reach a station within %d m of home "
                    "at least %d%% of the time" % (DAY_FROM_S // 3600, DAY_TO_S // 3600, HOME_RADIUS_M, HOME_SHARE * 100),
    }
    files["meta.json"] = json.dumps(meta, indent=1, sort_keys=True) + "\n"
    chunk_ids = ["StationChunk%02d" % k for k in range(nchunks)]
    xml = ['<!-- Generated by tools/build_stations.py; do not edit. -->',
           '<!-- Stations: %s, retrieved %s. GTFS feed %s. Entrances: %s. -->' % (
               SOURCES["stations"]["name"], SOURCES["stations"]["retrieved"], feed_dates, SOURCES["entrances"]["name"]),
           '<resources>',
           '    <jsonData id="StationIndex" scope="glance" filename="idx.json"/>']
    xml += ['    <jsonData id="%s" scope="glance" filename="c%02d.json"/>' % (cid, k) for k, cid in enumerate(chunk_ids)]
    xml += ['</resources>', '']  # meta.json is provenance only, not bundled
    files["stations.xml"] = "\n".join(xml)
    mc = [
        "// Generated by tools/build_stations.py; do not edit.",
        "using Toybox.Application;",
        "",
        "(:glance)",
        "module StationData {",
        "    const COUNT = %d;" % len(stations),
        "    const CHUNK = %d;" % CHUNK,
        '    const SOURCE = "MTA %s, GTFS %s";' % (SOURCES["stations"]["retrieved"], feed["feed_end_date"][:4] + "-" + feed["feed_end_date"][4:6]),
        "",
        "    function chunk(k) {",
        "        return Application.loadResource([" + ", ".join("Rez.JsonData." + c for c in chunk_ids) + "][k]);",
        "    }",
        "",
        "    function index() { return Application.loadResource(Rez.JsonData.StationIndex); }",
        "}",
        "",
    ]
    generated = {out_dir / n: v for n, v in files.items()}
    generated[ROOT / "source/StationData.mc"] = "\n".join(mc)

    if args.check:
        stale = [str(p.relative_to(ROOT)) for p, v in generated.items() if not p.exists() or p.read_text() != v]
        extra = sorted(str(p.relative_to(ROOT)) for p in out_dir.glob("*") if p not in generated) if out_dir.exists() else []
        if stale or extra:
            print("out of date: " + ", ".join(stale + extra))
            return 1
        print("up to date: %d stations" % len(stations))
        return 0
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in out_dir.glob("*"):
        if p not in generated:
            p.unlink()
    for p, v in generated.items():
        p.write_text(v)
    size = sum(len(v) for p, v in generated.items() if p.suffix == ".json" and p.name != "meta.json")
    print("%d stations (%d platforms, %d entrances) in %d chunks, %d bytes of JSON; home: %s" % (
        len(stations), len(near), meta["entrances"], nchunks, size, ", ".join(meta["homeStations"])))
    return 0


def compact(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False) + "\n"


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--gtfs", default=str(SOURCES["gtfs"]["path"]))
    p.add_argument("--entrances", default=str(SOURCES["entrances"]["path"]))
    p.add_argument("--check", action="store_true", help="exit 1 when checked-in outputs differ")
    sys.exit(build(p.parse_args()))
