"""Validate the MoodBite demo dataset in data/.

Exit code 0 when every check passes, 1 otherwise.
Usage:  python scripts/check_data.py
"""

from __future__ import annotations

import csv
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
ZONES_SQL = ROOT / "supabase" / "migrations" / "20261020000200_zones.sql"

EXPECTED_RESTAURANTS = 50
DISHES_PER_RESTAURANT = (6, 8)
MIN_DISHES_PER_MOOD = 30
MIN_VEG_DISHES_PER_MOOD = 8
MIN_NONVEG_DISHES_PER_MOOD = 15
MIN_NONVEG_SHARE_PER_MOOD = 0.25
ZONE_RADIUS_KM = 5.0
MUMBAI_BBOX = (18.85, 19.32, 72.75, 73.00)  # lat_min, lat_max, lng_min, lng_max

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def read(name: str) -> list[dict]:
    with (DATA / name).open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def check_unique(rows: list[dict], key: str, label: str) -> None:
    dupes = [k for k, n in Counter(r[key] for r in rows).items() if n > 1]
    if dupes:
        fail(f"{label}: duplicate {key}: {dupes}")


def main() -> int:
    moods = read("moods.csv")
    zones = read("zones.csv")
    restaurants = read("restaurants.csv")
    dishes = read("dishes.csv")
    dish_moods = read("dish_moods.csv")

    check_unique(moods, "id", "moods")
    check_unique(zones, "id", "zones")
    check_unique(zones, "name", "zones")
    check_unique(restaurants, "id", "restaurants")
    check_unique(dishes, "id", "dishes")
    pairs = Counter((dm["dish_id"], dm["mood_id"]) for dm in dish_moods)
    if any(n > 1 for n in pairs.values()):
        fail("dish_moods: duplicate (dish_id, mood_id) pairs")

    mood_ids = {m["id"] for m in moods}
    if len(mood_ids) != 8:
        fail(f"moods: expected 8, found {len(mood_ids)}")

    # Zones must match the migration exactly.
    sql_zones = {
        m.group(1): (m.group(2), float(m.group(3)), float(m.group(4)))
        for m in re.finditer(r"\('(z\d+)',\s*'([^']+)',\s*([\d.]+),\s*([\d.]+)\)", ZONES_SQL.read_text(encoding="utf-8"))
    }
    csv_zones = {z["id"]: (z["name"], float(z["lat"]), float(z["lng"])) for z in zones}
    if sql_zones != csv_zones:
        fail("zones.csv does not match supabase/migrations/20261020000200_zones.sql")
    zone_names = {z["name"] for z in zones}
    zone_points = [(float(z["lat"]), float(z["lng"])) for z in zones]

    # Restaurants
    if len(restaurants) != EXPECTED_RESTAURANTS:
        fail(f"restaurants: expected {EXPECTED_RESTAURANTS}, found {len(restaurants)}")
    lat_min, lat_max, lng_min, lng_max = MUMBAI_BBOX
    for r in restaurants:
        rid = r["id"]
        if r["area"] not in zone_names:
            fail(f"{rid}: area '{r['area']}' is not a zone")
        try:
            lat, lng = float(r["lat"]), float(r["lng"])
        except ValueError:
            fail(f"{rid}: lat/lng not numeric")
            continue
        if not (lat_min <= lat <= lat_max and lng_min <= lng <= lng_max):
            fail(f"{rid}: coordinates ({lat}, {lng}) outside the Mumbai bounding box")
        nearest = min(haversine_km(lat, lng, zl, zg) for zl, zg in zone_points)
        if nearest > ZONE_RADIUS_KM:
            fail(f"{rid}: {nearest:.1f} km from the nearest zone centre (limit {ZONE_RADIUS_KM} km)")
        if r["price_level"] not in {"1", "2", "3", "4"}:
            fail(f"{rid}: price_level must be 1-4")
        for flag in ("is_open", "coords_verified"):
            if r[flag] not in {"true", "false"}:
                fail(f"{rid}: {flag} must be true/false")
        if not r["cuisine"].strip():
            fail(f"{rid}: no cuisine")

    # Dishes
    restaurant_ids = {r["id"] for r in restaurants}
    per_restaurant = Counter(d["restaurant_id"] for d in dishes)
    names_per_restaurant = defaultdict(list)
    for d in dishes:
        if d["restaurant_id"] not in restaurant_ids:
            fail(f"{d['id']}: unknown restaurant_id {d['restaurant_id']}")
        names_per_restaurant[d["restaurant_id"]].append(d["name"])
        if not d["price_inr"].isdigit() or int(d["price_inr"]) <= 0:
            fail(f"{d['id']}: price_inr must be a positive whole number")
        if d["is_veg"] not in {"true", "false"}:
            fail(f"{d['id']}: is_veg must be true/false")
        if not d["name"].strip() or not d["category"].strip():
            fail(f"{d['id']}: missing name or category")
    lo, hi = DISHES_PER_RESTAURANT
    for rid in sorted(restaurant_ids):
        n = per_restaurant.get(rid, 0)
        if not lo <= n <= hi:
            fail(f"{rid}: has {n} dishes (expected {lo}-{hi})")
        dupes = [k for k, c in Counter(names_per_restaurant[rid]).items() if c > 1]
        if dupes:
            fail(f"{rid}: duplicate dish names {dupes}")

    # Dish moods
    dish_ids = {d["id"] for d in dishes}
    veg = {d["id"]: d["is_veg"] == "true" for d in dishes}
    moods_per_dish = defaultdict(list)
    for dm in dish_moods:
        if dm["dish_id"] not in dish_ids:
            fail(f"dish_moods: unknown dish_id {dm['dish_id']}")
            continue
        if dm["mood_id"] not in mood_ids:
            fail(f"dish_moods: unknown mood_id {dm['mood_id']}")
            continue
        moods_per_dish[dm["dish_id"]].append(float(dm["weight"]))
    for did in sorted(dish_ids):
        weights = moods_per_dish.get(did, [])
        if not weights:
            fail(f"{did}: has no mood")
            continue
        if weights.count(1.0) != 1:
            fail(f"{did}: must have exactly one primary mood (weight 1.0)")
        secondaries = [w for w in weights if w != 1.0]
        if len(secondaries) > 2 or any(not 0.5 <= w <= 0.7 for w in secondaries):
            fail(f"{did}: at most 2 secondary moods with weight 0.5-0.7")

    print(f"{'mood':<12} {'dishes':>6} {'veg':>4} {'non-veg':>7} {'nv %':>5} {'primary':>7}")
    for mood in sorted(mood_ids):
        tagged = [dm for dm in dish_moods if dm["mood_id"] == mood and dm["dish_id"] in dish_ids]
        total = len(tagged)
        veg_count = sum(1 for dm in tagged if veg[dm["dish_id"]])
        primary = sum(1 for dm in tagged if float(dm["weight"]) == 1.0)
        nonveg_count = total - veg_count
        nonveg_share = nonveg_count / total if total else 0.0
        print(f"{mood:<12} {total:>6} {veg_count:>4} {nonveg_count:>7} {nonveg_share:>5.0%} {primary:>7}")
        if total < MIN_DISHES_PER_MOOD:
            fail(f"mood {mood}: {total} dishes (need >= {MIN_DISHES_PER_MOOD})")
        if veg_count < MIN_VEG_DISHES_PER_MOOD:
            fail(f"mood {mood}: {veg_count} veg dishes (need >= {MIN_VEG_DISHES_PER_MOOD})")
        if nonveg_count < MIN_NONVEG_DISHES_PER_MOOD:
            fail(f"mood {mood}: {nonveg_count} non-veg dishes (need >= {MIN_NONVEG_DISHES_PER_MOOD})")
        if nonveg_share < MIN_NONVEG_SHARE_PER_MOOD:
            fail(f"mood {mood}: non-veg share {nonveg_share:.0%} (need >= {MIN_NONVEG_SHARE_PER_MOOD:.0%})")

    unverified = sum(1 for r in restaurants if r["coords_verified"] != "true")
    print(
        f"\nrestaurants={len(restaurants)} dishes={len(dishes)} dish_moods={len(dish_moods)} "
        f"veg_dishes={sum(veg.values())} coords_unverified={unverified}"
    )

    if errors:
        print(f"\nFAILED ({len(errors)} problems):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
