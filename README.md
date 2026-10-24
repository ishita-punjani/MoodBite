# MoodBite

**A mood-based food ordering app for Mumbai.** Pick how you feel, or tell the chat assistant, and MoodBite recommends five dishes from restaurants near you. The ranking uses your mood, the distance, an optional price limit, your diet and your past orders, and the Gemini API chooses and explains the final five.

Built with Flutter (Android) and Supabase as a mini project at MPSTME, NMIMS Mumbai (2026-27).

> **Demo data notice.** The 50 restaurant names are real Mumbai places, but the menus, prices and mood tags are illustrative and are **not** the restaurants' real menus. Delivery tracking is **simulated**. No real payment is taken and no real order is placed.

## Demo

A 40-second screen recording on a physical Android phone (no audio): choosing a delivery area, mood-based recommendations, the chat assistant, checkout, and the simulated delivery tracker. The road route comes from the public OSRM demo server; when it is unavailable the app draws a straight line, as it does in this recording.

https://github.com/user-attachments/assets/b1691f98-c0e5-493d-94a1-b5c6cc5b7cbf


## Features

- **Passwordless sign-in** with an email one-time code (6 digits) or a Google account
- **Eight moods** (happy, stressed, sad, tired, celebratory, adventurous, romantic, energetic) with a diet filter (Any, Veg, Non-veg only) and an optional price limit
- **Five recommendations** with a one-line reason each and an "AI pick" or "Quick pick" badge showing whether Gemini or the database fallback chose them
- **Ask tab**, a food chatbot that turns a message such as "something warm under 300" into dishes from the database
- **Browse and search** 50 restaurants (nearest first) and 355 dishes, with a price level and the dish price range on each restaurant
- **Cart and checkout** for one restaurant at a time, with saved addresses and a Mumbai-only delivery check that the server enforces again
- **Simulated delivery tracking** on an OpenStreetMap map with a road route, labeled "Demo delivery"
- **Meal-time notifications** (opt-in) and friendly loading messages

## How the recommendation works

1. The database keeps only dishes from open restaurants that match the diet, price limit and delivery area (inside a Mumbai zone).
2. Each candidate gets a score: `0.40 x mood fit + 0.25 x semantic similarity + 0.15 x personalization + 0.20 x distance decay`. The weights live in the `app_config` table.
3. The top 20 go to the Gemini API in one call that contains only dish details and a rounded distance, never the user's name, email, phone number or coordinates. Gemini returns five dish IDs with a reason each.
4. Every ID is checked against the candidate list. If the call fails, times out, hits a quota limit or returns bad data, the app returns the top five by score with a standard reason.

## Tech stack

| Layer | Technology |
|---|---|
| App | Flutter and Dart (Android, minimum Android 7.0 / API 24), Riverpod, go_router |
| Backend | Supabase: Auth, PostgreSQL with PostGIS and pgvector, SQL functions, Edge Functions (TypeScript) |
| AI | Gemini API: text embeddings and a Flash-class model for ranking, explanations and chat |
| Maps | flutter_map with OpenStreetMap tiles, OSRM public demo server for routes |
| Other | geolocator, flutter_local_notifications, google_sign_in |

## Repository layout

```
lib/                  Flutter app, grouped by feature (auth, home, browse, chat, cart, orders, tracking, profile, ...)
test/                 Flutter unit and widget tests
supabase/
  migrations/         Database schema, row-level security, SQL functions (apply in filename order)
  functions/recommend/  Edge Function: Gemini ranking, chat, fallback, daily cap
  seed.sql            50 restaurants, 355 dishes, 8 moods, 27 delivery zones
data/                 CSV source of the demo dataset
scripts/              Dataset generation, geocoding, checks and the embedding script
assets/logo/          App logo and launcher icon sources
docs/diagrams/        Mermaid sources of the architecture and flow diagrams
```

## Getting started

You need your own Supabase project and Gemini API key. **Never commit secrets.** The app reads only public values from `.env`; server keys stay in Supabase.

**Prerequisites:** Flutter (tested with 3.47.7), Android Studio with an emulator image that includes Google Play (needed for Google sign-in) or a physical Android phone, Node.js, the Supabase CLI and Python 3.

1. **Create a Supabase project** and note the project URL and the publishable (anon) key.
2. **Create the database.** In the Supabase SQL editor, run every file in `supabase/migrations/` in filename order, then run `supabase/seed.sql`.
3. **Load the embeddings.** Get a Gemini API key from Google AI Studio, then in a terminal set `GEMINI_API_KEY`, `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (the service key stays on your machine) and run `python scripts/embed.py`. Use `--dry-run` first to see what it will embed.
4. **Configure sign-in.** In Supabase Authentication, enable Email (add `{{ .Token }}` to the Magic Link and Confirm signup templates so the email shows a code, and set up custom SMTP). For Google sign-in, create a Web and an Android OAuth client in Google Cloud (the Android client needs your package name and debug SHA-1), then enable the Google provider in Supabase with the Web client ID and secret.
5. **Deploy the Edge Function.**
   ```
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase secrets set GEMINI_API_KEY=your_key
   supabase functions deploy recommend
   ```
   Optional secrets: `GEMINI_MODEL` (model name) and `AI_DAILY_CAP` (Gemini calls per user per day).
6. **Configure the app.** Copy `.env.example` to `.env` and fill in `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `GOOGLE_WEB_CLIENT_ID`.
7. **Run it.**
   ```
   flutter pub get
   flutter run
   ```
   On an emulator, set the location to Mumbai, for example with `adb emu geo fix 72.8295 19.0596`. Outside Mumbai the app asks you to choose a delivery area instead.

## Tests

```
flutter analyze
flutter test
node --test supabase/functions/recommend/logic.test.ts
```

The Flutter tests cover validators, the Mumbai zone rule, repositories and the main screens with fake data. The Node tests cover the Edge Function's parsing, validation, fallback, daily cap and privacy rules without calling Gemini.

## Limitations and known issues

- Demo dataset, no dish photos, one restaurant per cart, straight-line distances measured from the center of the chosen area.
- The same 2 minutes 45 seconds demo delivery for every order.
- The Gemini free tier is rate-limited (the app falls back to database ranking when a limit is reached). The OpenStreetMap and OSRM public servers are for light use only.
- After tapping "Track order" right away on the confirmation screen, the Android back button leaves the app. Open tracking from the Orders tab instead.
- Android only, Mumbai only.

## Acknowledgements

- Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright). Routes from the [OSRM](https://project-osrm.org) demo server.
- Built with [Flutter](https://flutter.dev), [Supabase](https://supabase.com), [PostGIS](https://postgis.net), [pgvector](https://github.com/pgvector/pgvector) and the [Gemini API](https://ai.google.dev).
- **AI-assisted development.** Claude and Claude Code helped generate and draft code and documentation. The authors ran the application, executed the test cases on an Android emulator and a physical phone, and recorded the results.


## License

All rights reserved by authors
