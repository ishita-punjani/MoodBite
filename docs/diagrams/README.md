# Diagram sources

Render each `.mmd` file with Mermaid (for example https://mermaid.live), export as PNG or SVG, and restyle in Word or PowerPoint as needed.

| File | Figure | Plain-text description |
|---|---|---|
| `fig4_1_architecture.mmd` | 4.1 | Flutter app (screens, Riverpod/go_router state, local services) talks to Supabase (Auth, Postgres with PostGIS and pgvector, SQL functions, the `recommend` Edge Function). Only the Edge Function calls Gemini. OpenStreetMap tiles and the OSRM demo server are used by the tracking screen. |
| `fig4_2_er_diagram.mmd` | 4.2 | Tables from `supabase/migrations`: profiles, addresses, zones, restaurants, dishes, moods, dish_moods, orders, order_items, recommendation_feedback, ai_usage, linked to `auth.users`. |
| `fig4_3_recommendation_pipeline.mmd` | 4.3 | Mood in, hard filters, candidate selection, weighted score, top 20, one Gemini rerank with validation, templated fallback. |
| `fig4_4_system_flowchart.mmd` | 4.4 | Sign-in, profile, area choice, mood/chat/browse, cart, Mumbai check, order, tracking. |
| `fig4_5_delivery_status_flow.mmd` | 4.5 | Five demo statuses with the elapsed-time thresholds from `tracking_logic.dart`. |

Not rendered or checked in a Mermaid viewer by Claude; if a diagram fails to render, send the error text.
