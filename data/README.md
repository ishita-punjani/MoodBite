# MoodBite demo dataset

**Demo data.** Restaurant names are real Mumbai restaurants, but every menu, price and mood tag here is
illustrative, written for this academic project. These are not the restaurants' actual menus or prices.
Coordinates come from OpenStreetMap (c) OpenStreetMap contributors, ODbL, or from area centroids where
no confident match was found (`coords_verified=false`, see `REVIEW.md`).

| File | Rows | Contents |
|---|---|---|
| `moods.csv` | 8 | id, label, emoji, description (the description is what gets embedded) |
| `zones.csv` | 27 | Mumbai delivery zone centres (same rows as migration `20261020000200_zones.sql`) |
| `restaurants.csv` | 50 | id, name, area, address, lat, lng, cuisine (pipe-separated), price_level 1-4, is_open, coords_verified |
| `dishes.csv` | 355 | id, restaurant_id, name, description, price_inr, is_veg, category |
| `dish_moods.csv` | 787 | dish_id, mood_id, weight (1.0 primary, 0.7 / 0.5 secondary) |
| `geocode_report.csv` | 50 | what Nominatim matched for each restaurant |
| `geocode_cache.json` | - | raw Nominatim responses, so re-running the geocoder makes no new requests |

## Pipeline (run from the repo root)

```
python scripts/generate_dataset.py   # writes the CSVs (coordinates reset to area centroids)
python scripts/geocode.py            # looks up coordinates (uses the cache), writes REVIEW.md
python scripts/check_data.py         # must print ALL CHECKS PASSED
python scripts/build_seed.py         # writes supabase/seed.sql
python scripts/embed.py --dry-run    # shows the texts that will be embedded
python scripts/embed.py              # AFTER the seed is in Supabase; needs keys in env vars
```

Edit menus or mood tags in `scripts/generate_dataset.py`, not in the CSVs, then run the pipeline again.
If you fix coordinates by hand in `restaurants.csv`, do NOT run `generate_dataset.py` or `geocode.py` again
afterwards (they would overwrite your fix); run only `check_data.py` and `build_seed.py`.

## Veg / non-veg balance

`check_data.py` requires every mood to have at least 15 non-veg dishes and at least 25% non-veg tags.
Dishes added in the rebalance are listed in `ADDITIONS` in `generate_dataset.py` and have ids `d341`-`d355`,
so the ids of the original 340 dishes (and any embeddings stored against them) did not change.
After re-seeding, run `embed.py` so the 15 new dishes get embeddings (it embeds every dish and mood on each run).
The seed upsert does not touch the `embedding` column of existing dishes.
