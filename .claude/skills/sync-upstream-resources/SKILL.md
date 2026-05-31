---
name: sync-upstream-resources
description: >-
  Scan this DragnCards fork for new content and missing resources versus its
  upstreams, then INTEGRATE them locally — not just download art. Covers BOTH
  plugins (Marvel Champions, Lord of the Rings LCG): when upstream adds a new
  playable feature (cards, prebuilt decks, quests/scenarios), this builds the
  local plugin files that make it playable (per-set card TSVs, deck definitions,
  deck-menu entries) and downloads the card IMAGES into the offline mirrors. Also
  reports new upstream CODE commits (never auto-merges). Use when the user wants
  to check for, pull in, or make playable new upstream content, sync the plugins,
  or download missing card art to keep the offline copy current.
---

# Sync & integrate upstream content (DragnCards fork)

This fork is kept playable **offline**. Two separate "upstreams" feed it:

| Upstream | Provides | Treatment |
|----------|----------|-----------|
| **Live plugins** on `dragncards.com` (MC = id **2**, LOTR = id **1**) | Authoritative cards, prebuilt decks, game_def, images | **Integrated automatically** (cards/decks/menus) + images downloaded |
| **git remote `upstream`** (`seastan/dragncards`) | App source code | **Report only** — never auto-merged |

Local plugins live in Postgres `dragncards_dev` as MC id **8** / LOTR id **7**, rebuilt from files under `backend/priv/dragncards-{mc,lotrlcg}-plugin/{jsons,tsvs}/` + `backend/priv/cardDb.json`. Images are served locally from `frontend/public/{mc-cards,lotrlcg-cards}/` (gitignored).

Helper (does the deterministic work):
```
scripts/sync_upstream_resources.py report    [mc|lotr|all]              # what's new/missing
scripts/sync_upstream_resources.py integrate [mc|lotr|all] [--apply]    # BUILD the new feature's files
scripts/sync_upstream_resources.py images    [mc|lotr|all] [--apply]    # download missing card art
```
Flags: `--refresh` (refetch cached live JSON), `--retry-unavailable` (retry 403 images), `--workers N`.

## Procedure

1. **Confirm the stack is up** — `docker ps --format '{{.Names}}' | grep dragncards` (backend/postgres/frontend). `integrate`/`report` need the DB to know what's already local.

2. **Scan** — `report all`. Summarize per plugin: new cards (`+N`), local-only cards (`-N`, usually fan "Custom Set" content — leave them), new decks, game_def key diffs, missing images, and new code commits.

3. **Integrate new playable content** — for any plugin with new cards/decks, dry-run first then apply:
   `python3 scripts/sync_upstream_resources.py integrate <plugin>` then `... integrate <plugin> --apply`.
   With `--apply` it writes, from the authoritative live plugin:
   - **Cards** → new card faces become TSV rows mapped 1:1 to the plugin's TSV header. LOTR groups by `setUuid` into `tsvs/<setUuid>.tsv` (matching the ALeP convention); plugins/cards without a setUuid go to `tsvs/zz-synced-<plugin>.tsv`. Double-sided cards emit consecutive A then B rows (`TsvProcess` assigns sides by row order). It validates by simulating `TsvProcess`.
   - **Decks** → new `preBuiltDecks` entries written to `jsons/zz-synced-<plugin>-decks.json`; it checks every referenced card id resolves.
   - **Menu (new top-level cycle)** → auto-written to `jsons/zz-synced-<plugin>.menu.json` (safe: separate menu files concatenate on merge).
   - **Menu (addition to an EXISTING cycle)** → NOT auto-edited (to preserve the file's formatting/comments). The script prints a `MENU EDIT NEEDED` line with the owning file, the cycle/quest path, and the exact node JSON.

4. **Apply any `MENU EDIT NEEDED` items** yourself — open the named menu file and insert the printed node into the matching cycle's `subMenus` (placed after its siblings, like the existing quests). A quest node holds both difficulties, e.g. `{"label":"ALeP <Quest>","deckLists":[{"label":"id:easy","deckListId":"EA<n>"},{"label":"id:normal","deckListId":"QA<n>"}]}`. If the node has only `deckLists` (a new scenario added to an existing pack), merge those entries into the existing pack node's `deckLists`. Keep the file valid JSON.

5. **Download images** — `images <plugin> --apply`. Pulls from the canonical CDN (Cerebro for MC, S3 `cards/English/` for LOTR) into the mirror. 403s (fan/custom or not-yet-uploaded art) are recorded in `<mirror>/.sync-unavailable.txt` and skipped next time — **not a regression**.

6. **Apply** — re-import the affected plugin(s) and restart to bust the 1-hour ETS cache:
   ```
   docker exec dragncards-backend-1 sh -lc 'cd /app && mix run priv/import_mc_plugin.exs'      # MC
   docker exec dragncards-backend-1 sh -lc 'cd /app && mix run priv/import_lotrlcg_plugin.exs' # LOTR
   docker restart dragncards-backend-1
   ```

7. **Verify** — re-run `report <plugin> --refresh`; expect **+0 new cards / +0 new decks** and images complete. Spot-check art: `curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/<mirror>/<name>` → `200`. Confirm a new deck key is present: `... game_def->'preBuiltDecks' ? '<deckId>'`.

## Guardrails
- **Never touch the offline image config.** The localized `imageUrlPrefix` (`/mc-cards`, `/lotrlcg-cards`), local card backs, tokens, backgrounds, and Hall-of-Beorn TSV rewrites are intentional (memory `[[offline-image-readiness]]`). `images` downloads from canonical remotes independently of config and only writes into the mirrors.
- **Synced files are namespaced `zz-synced-*`** so they're easy to spot and never collide with hand-maintained files. `integrate` only ever processes cards/decks **not already local**, so it's idempotent.
- **Inspect, don't blindly trust, the menu plan.** Placement (which cycle/pack, ordering) is the one spot needing judgment — `integrate` automates the unambiguous cases and defers ambiguous existing-cycle inserts to you.
- New upstream **code** commits: report and point to memory `[[fork-upstream-relationship]]`; do not auto-merge.
- Worked example + the ALeP quest recipe this generalizes: memory `[[offline-image-readiness]]` (The Brandywine Pursuit, 2026-05-29). Live plugin IDs are constants at the top of the script.
