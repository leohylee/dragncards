---
name: sync-upstream-resources
description: >-
  Scan this DragnCards fork for discrepancies and missing resources versus its
  upstreams, then sync them locally. Covers BOTH plugins (Marvel Champions and
  Lord of the Rings LCG): new/changed cards, prebuilt decks, game_def changes,
  and especially missing card IMAGES — which it downloads into the local offline
  mirrors. Also reports new upstream CODE commits (never auto-merges). Use when
  the user wants to check for new upstream content, find what's out of date or
  missing, sync plugins, or download missing card art to keep the offline copy current.
---

# Sync upstream resources (DragnCards fork)

This fork is kept playable **offline**. Two separate "upstreams" feed it:

| Upstream | What it provides | How this skill treats it |
|----------|------------------|--------------------------|
| **Live plugins** on `dragncards.com` (MC = id **2**, LOTR = id **1**) | Authoritative card data, prebuilt decks, game_def, and card images | **Automatically** audits + downloads missing images; reports data diffs |
| **git remote `upstream`** (`seastan/dragncards`) | App source code | **Report only** — never auto-merged (see the documented merge process) |

Local plugins live in Postgres `dragncards_dev` as MC id **8** / LOTR id **7**, rebuilt from files under `backend/priv/dragncards-{mc,lotrlcg}-plugin/` + `backend/priv/cardDb.json`. Images are served locally from `frontend/public/mc-cards/` and `frontend/public/lotrlcg-cards/` (both gitignored).

The helper does the deterministic work:
```
scripts/sync_upstream_resources.py report [mc|lotr|all]
scripts/sync_upstream_resources.py images [mc|lotr|all] [--apply]
```
Flags: `--refresh` (refetch the cached live JSON), `--retry-unavailable` (retry images previously recorded 403), `--workers N`.

## Procedure

1. **Confirm the stack is up** (needed for the local-DB diff and for re-import):
   `docker ps --format '{{.Names}}' | grep dragncards` — expect backend/postgres/frontend. The image audit/download works even if the DB is down (it only needs the live plugin + the filesystem).

2. **Scan** — run `python3 scripts/sync_upstream_resources.py report all`. Summarize for the user, per plugin:
   - new upstream cards (`+N`), local-only cards (`-N` — usually fan "Custom Set" content, expected to stay local), new/removed decks, game_def key changes, and **missing images**.
   - new upstream code commits.

3. **Download missing images** (the "download resources to local" step) — for any plugin showing missing images:
   `python3 scripts/sync_upstream_resources.py images <plugin> --apply`
   - Pulls from the canonical CDN (Cerebro for MC, S3 `cards/English/` for LOTR) into the local mirror.
   - Failures are recorded in `<mirror>/.sync-unavailable.txt` and skipped next time. These are normally fan/custom images not on the official CDN (broken on live too) — **not a regression**. Report the count; don't keep retrying unless the user asks (`--retry-unavailable`).
   - This step alone needs **no re-import** for art belonging to cards already in the local card_db.

4. **Sync new card/deck DATA** (only if step 2 reported new cards/decks the user wants). This needs judgment — **do not script it blindly**; follow the per-plugin workflow in memory `[[mc-plugin-update-workflow]]`:
   - Pull the new card objects from the cached live JSON (path printed by the script; in the system temp dir as `dragncards-live-<plugin>.json`).
   - MC: append the new pack's rows to `tsvs/marvelcdb.tsv` (watch double-sided **row ordering** — A-side row must immediately precede its B-side), add deck entries to `preBuiltDecks.json` + `deckMenu.json`.
   - LOTR: ALeP/quest content goes in the ALeP TSVs + quest JSONs (ALeP takes precedence over `cardDb.json` at import); official cards merge via `cardDb.json`.
   - After editing data, re-run `images <plugin> --apply` to fetch the new cards' art.

5. **Apply data changes** (only if step 4 ran) — re-import the affected plugin(s) and restart the backend to bust the 1-hour ETS plugin cache:
   ```
   docker exec dragncards-backend-1 sh -lc 'cd /app && mix run priv/import_mc_plugin.exs'
   docker exec dragncards-backend-1 sh -lc 'cd /app && mix run priv/import_lotrlcg_plugin.exs'
   docker restart dragncards-backend-1
   ```

6. **Code commits** — if `report` showed new upstream commits, tell the user and point to the documented merge process (memory `[[fork-upstream-relationship]]`). Do **not** merge automatically; the fork has local customizations to preserve.

## Guardrails
- **Never touch the offline image config.** The localized `imageUrlPrefix` (`/mc-cards`, `/lotrlcg-cards`), local card backs, tokens, backgrounds, and the 4 Hall-of-Beorn TSV rewrites are intentional local customizations (memory `[[offline-image-readiness]]`). The script downloads from canonical remotes independently of this config and only writes image files into the mirrors.
- The script is **idempotent** — only missing images are fetched. Safe to re-run anytime.
- Verify a sample after downloading: `curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/lotrlcg-cards/<name>` should be `200`.
- If live plugin IDs ever change, they're constants at the top of `scripts/sync_upstream_resources.py`.
