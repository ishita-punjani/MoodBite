"""Compute 768-dim Gemini embeddings for every dish and mood and store them in Supabase.

Run ONCE after the seed is imported. Uses only the Python standard library.

Required environment variables (set them in your terminal session; never put
them in the Flutter .env or commit them):
  GEMINI_API_KEY              Google AI Studio key
  SUPABASE_URL                https://<project>.supabase.co
  SUPABASE_SERVICE_ROLE_KEY   service-role key (needed to write catalogue tables)
Optional:
  EMBED_MODEL                 default "gemini-embedding-001" (check current name in the Gemini docs)

Usage:
  python scripts/embed.py --dry-run    # print the texts that would be embedded (no network, no keys)
  python scripts/embed.py              # embed and write to Supabase
"""

from __future__ import annotations

import csv
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
DIMENSIONS = 768
BATCH_SIZE = 50
MAX_RETRIES = 4
TASK_TYPE = "SEMANTIC_SIMILARITY"


def read(name: str) -> list[dict]:
    with (DATA / name).open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def dish_texts() -> list[tuple[str, str]]:
    cuisines = {r["id"]: r["cuisine"].replace("|", ", ") for r in read("restaurants.csv")}
    return [
        (
            d["id"],
            f"{d['name']}. {d['description']}. Category: {d['category'].replace('_', ' ')}. "
            f"Cuisine: {cuisines[d['restaurant_id']]}. {'Vegetarian' if d['is_veg'] == 'true' else 'Non-vegetarian'}.",
        )
        for d in read("dishes.csv")
    ]


def mood_texts() -> list[tuple[str, str]]:
    return [(m["id"], m["description"]) for m in read("moods.csv")]


def http_json(url: str, body: dict | None, headers: dict, method: str = "POST") -> object:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Content-Type": "application/json", **headers})
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read().decode("utf-8")
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and attempt < MAX_RETRIES:
                delay = 2 ** attempt * 5
                print(f"  HTTP {e.code}, retrying in {delay}s")
                time.sleep(delay)
                continue
            raise SystemExit(f"HTTP {e.code} from {urllib.parse.urlsplit(url).netloc}: {e.read().decode('utf-8')[:300]}")
    raise SystemExit("unreachable")


def normalise(vector: list[float]) -> list[float]:
    norm = math.sqrt(sum(v * v for v in vector)) or 1.0
    return [v / norm for v in vector]


def embed_batch(texts: list[str], model: str, api_key: str) -> list[list[float]]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:batchEmbedContents"
    body = {
        "requests": [
            {
                "model": f"models/{model}",
                "content": {"parts": [{"text": t}]},
                "taskType": TASK_TYPE,
                "outputDimensionality": DIMENSIONS,
            }
            for t in texts
        ]
    }
    result = http_json(url, body, {"x-goog-api-key": api_key})
    vectors = [e["values"] for e in result["embeddings"]]
    for v in vectors:
        if len(v) != DIMENSIONS:
            raise SystemExit(f"expected {DIMENSIONS} dimensions, got {len(v)}; check EMBED_MODEL")
    # Truncated (MRL) Gemini embeddings are not unit length; normalise for cosine similarity.
    return [normalise(v) for v in vectors]


def store(table: str, row_id: str, vector: list[float], supabase_url: str, service_key: str) -> None:
    url = f"{supabase_url}/rest/v1/{table}?id=eq.{urllib.parse.quote(row_id)}"
    headers = {"apikey": service_key, "Authorization": f"Bearer {service_key}", "Prefer": "return=minimal"}
    http_json(url, {"embedding": "[" + ",".join(f"{v:.7f}" for v in vector) + "]"}, headers, method="PATCH")


def main() -> int:
    items = [("moods", i, t) for i, t in mood_texts()] + [("dishes", i, t) for i, t in dish_texts()]

    if "--dry-run" in sys.argv:
        for table, row_id, text in items[:12]:
            print(f"{table}/{row_id}: {text}")
        print(f"... {len(items)} texts in total ({len(mood_texts())} moods, {len(dish_texts())} dishes)")
        return 0

    missing = [k for k in ("GEMINI_API_KEY", "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY") if not os.environ.get(k)]
    if missing:
        print(f"Missing environment variables: {', '.join(missing)}")
        return 1
    api_key = os.environ["GEMINI_API_KEY"]
    supabase_url = os.environ["SUPABASE_URL"].rstrip("/")
    service_key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    model = os.environ.get("EMBED_MODEL", "gemini-embedding-001")

    for start in range(0, len(items), BATCH_SIZE):
        batch = items[start:start + BATCH_SIZE]
        vectors = embed_batch([t for _, _, t in batch], model, api_key)
        for (table, row_id, _), vector in zip(batch, vectors):
            store(table, row_id, vector, supabase_url, service_key)
        print(f"embedded {start + len(batch)}/{len(items)}")
        time.sleep(1)  # stay gentle with free-tier rate limits

    print("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
