---
name: backup-offline-resources
description: >-
  Back up the DragnCards resources that are NOT in git into one timestamped .zip
  ready to upload to a cloud drive / external disk. Captures the card-image
  mirrors (mc-cards + lotrlcg-cards) and, optionally, the RingsDB+MarvelsDB
  sibling databases & images, the Claude memory notes, and a self-contained git
  bundle. Use when the user wants to back up the project, make a zip to upload,
  protect against a computer failure, or safeguard the offline card images.
---

# Back up offline resources (DragnCards)

Most of this project is **already safe on GitHub** (`origin`) — all source, both plugin dirs, `cardDb.json`, the sync skill. This skill packages only what is **NOT in git** so the user can drop it on a cloud drive.

Helper: `scripts/backup_offline_resources.sh` — builds one `.zip` (default to `~/Desktop`).

| Flag | Includes | Default |
|------|----------|---------|
| `--images` / `--no-images` | DragnCards `frontend/public/{mc-cards,lotrlcg-cards}` (~2.2 GB) | ON |
| `--siblings` | RingsDB + MarvelsDB MySQL dumps + RingsDB card images (~1.5 GB) | off |
| `--memory` | `~/.claude/.../memory/*.md` curated notes (~28 KB) | off |
| `--git-bundle` | self-contained repo + full history snapshot | off |
| `--out DIR` | output directory | `~/Desktop` |

## Procedure
1. Ask the user (or recall) which components they want; the common request is `--images --siblings`.
2. If `--siblings`: the RingsDB/MarvelsDB MySQL containers may be down. The script auto-starts a sibling container only when needed for the dump and **returns it to its prior state** afterward. Card-image components need no containers.
3. Run, e.g.: `bash scripts/backup_offline_resources.sh --images --siblings`
4. Report the resulting zip path + size, and surface any `⚠` warnings (e.g., a sibling DB that couldn't be dumped).
5. **Always end by reminding the user to upload the zip OFF this machine** (cloud drive / external disk). An on-disk backup does not protect against the hardware failure they're guarding against — note that the repo's older `backup-all.sh` and the `backup` git remote both write to the same disk.

## Notes / guardrails
- **Idempotent & read-only** w.r.t. tracked files — it only reads images/DBs and writes a zip. Safe to re-run.
- Card art is *also* re-downloadable later via `scripts/sync_upstream_resources.py images --apply` (Cerebro/S3); the zip is insurance against those CDNs disappearing.
- Intentionally **omitted**: the DragnCards Postgres DB (users/saved games — acceptable to lose per the project owner) and anything reproducible (node_modules, _build, deps).
- MarvelsDB card images are MC duplicates already inside `mc-cards`, so only RingsDB images are bundled under `--siblings`.
- Verify a finished zip with `unzip -l <zip> | tail` if the user wants a content check.
