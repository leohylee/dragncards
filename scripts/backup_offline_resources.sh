#!/bin/bash
# Back up the DragnCards resources that are NOT in git into a single .zip for cloud upload.
#
# Everything tracked in git is already on GitHub (origin); this captures the rest.
# Components (toggle with flags):
#   --images        (default ON)  DragnCards card images: frontend/public/{mc-cards,lotrlcg-cards}
#   --siblings      (default OFF) RingsDB + MarvelsDB MySQL dumps + RingsDB card images
#   --memory        (default OFF) ~/.claude/.../memory/*.md curated project notes
#   --git-bundle    (default OFF) self-contained snapshot of the repo + full history
#   --out DIR       output directory (default: ~/Desktop)
#   --no-images     turn images off
# Re-runnable; never modifies tracked files. Sibling DB containers are started only if
# needed and returned to their prior state.

REPO="/Users/leo/Projects/dragncards"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$HOME/Desktop"
DO_IMAGES=1; DO_SIBLINGS=0; DO_MEMORY=0; DO_BUNDLE=0
WARN=()

while [ $# -gt 0 ]; do
  case "$1" in
    --images) DO_IMAGES=1 ;;
    --no-images) DO_IMAGES=0 ;;
    --siblings) DO_SIBLINGS=1 ;;
    --memory) DO_MEMORY=1 ;;
    --git-bundle) DO_BUNDLE=1 ;;
    --out) shift; OUT_DIR="$1" ;;
    *) echo "unknown flag: $1"; exit 1 ;;
  esac
  shift
done

mkdir -p "$OUT_DIR"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/meta" "$STAGE/siblings"
ZIP="$OUT_DIR/dragncards-backup_${TS}.zip"
echo "🗄  DragnCards offline backup → $ZIP"

dc() { # docker compose wrapper (v2 then v1)
  if docker compose version >/dev/null 2>&1; then docker compose "$@"; else docker-compose "$@"; fi
}

# ---- DragnCards card images ----
if [ "$DO_IMAGES" = "1" ]; then
  echo "📦 card images (mc-cards + lotrlcg-cards)…"
  ( cd "$REPO/frontend/public" && zip -r -0 -q "$ZIP" mc-cards lotrlcg-cards -x '*.DS_Store' ) \
    && echo "   ✓ added" || WARN+=("DragnCards image zip failed")
fi

# ---- DragnCards Postgres plugins/users (small, optional safety net) is intentionally skipped
#      (plugins rebuild from tracked files; user/saved-game loss is acceptable per project owner).

# ---- siblings: RingsDB + MarvelsDB ----
backup_sibling_db() {
  local name="$1" container="$2" user="$3" pass="$4" db="$5"
  local compose="/Users/leo/Projects/$name/docker-compose.yml" started=0
  if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    if [ -f "$compose" ]; then
      echo "   starting $container (was down)…"
      dc -f "$compose" up -d >/dev/null 2>&1 && started=1
      for _ in $(seq 1 30); do
        docker exec "$container" sh -lc "mysqladmin -u${user} -p${pass} ping" >/dev/null 2>&1 && break
        sleep 2
      done
    else
      WARN+=("$name: container down and no compose file; DB not dumped"); return
    fi
  fi
  if docker exec "$container" sh -lc "mysqldump -u${user} -p${pass} ${db}" > "$STAGE/siblings/${name}.sql" 2>/dev/null && [ -s "$STAGE/siblings/${name}.sql" ]; then
    echo "   ✓ ${name} DB dump ($(du -h "$STAGE/siblings/${name}.sql" | cut -f1))"
  else
    WARN+=("$name: mysqldump produced no output (check creds/container)")
  fi
  [ "$started" = "1" ] && { echo "   stopping $container (restoring prior state)…"; dc -f "$compose" down >/dev/null 2>&1; }
}

if [ "$DO_SIBLINGS" = "1" ]; then
  echo "📦 RingsDB + MarvelsDB…"
  backup_sibling_db ringsdb   ringsdb-mysql   ringsdb   ringsdb   ringsdb
  backup_sibling_db marvelsdb marvelsdb-mysql marvelsdb marvelsdb marvelsdb
  # RingsDB card images (MarvelsDB images are MC duplicates already in mc-cards)
  if [ -d /Users/leo/Projects/ringsdb/web/bundles/cards ]; then
    echo "   ringsdb card images → tar.gz…"
    tar -czf "$STAGE/siblings/ringsdb-cards.tar.gz" -C /Users/leo/Projects/ringsdb/web/bundles cards 2>/dev/null \
      && echo "   ✓ ($(du -h "$STAGE/siblings/ringsdb-cards.tar.gz" | cut -f1))" || WARN+=("ringsdb image tar failed")
  fi
fi

# ---- Claude memory notes ----
if [ "$DO_MEMORY" = "1" ]; then
  MEM="$HOME/.claude/projects/$(echo "$REPO" | sed 's#/#-#g')/memory"
  if [ -d "$MEM" ]; then cp -R "$MEM" "$STAGE/meta/claude-memory" && echo "📦 ✓ Claude memory notes"; else WARN+=("memory dir not found: $MEM"); fi
fi

# ---- git bundle ----
if [ "$DO_BUNDLE" = "1" ]; then
  echo "📦 git bundle…"
  git -C "$REPO" bundle create "$STAGE/meta/dragncards.bundle" --all >/dev/null 2>&1 \
    && echo "   ✓ ($(du -h "$STAGE/meta/dragncards.bundle" | cut -f1))" || WARN+=("git bundle failed")
fi

# ---- manifest ----
{
  echo "DragnCards offline backup — $(date)"
  echo "Host: $(hostname) | repo HEAD: $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null) on $(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "Included: images=$DO_IMAGES siblings=$DO_SIBLINGS memory=$DO_MEMORY git-bundle=$DO_BUNDLE"
  echo
  echo "NOT included (recoverable elsewhere):"
  echo "  - All source code, plugin files, cardDb.json, the sync skill → on GitHub (origin)."
  echo "  - DragnCards Postgres DB (users/saved games) → intentionally omitted."
  echo "  - node_modules / _build / deps → regenerated on build."
  echo "  - Card art is also re-downloadable via scripts/sync_upstream_resources.py images --apply,"
  echo "    but is bundled here as insurance against CDN loss."
} > "$STAGE/meta/MANIFEST.txt"
( cd "$STAGE" && zip -r -q "$ZIP" meta siblings 2>/dev/null )

echo ""
echo "✅ Done: $ZIP  ($(du -h "$ZIP" | cut -f1))"
if [ ${#WARN[@]} -gt 0 ]; then printf '⚠  %s\n' "${WARN[@]}"; fi
echo "➡  UPLOAD THIS FILE OFF THIS MACHINE (cloud drive / external disk). An on-disk copy is not a backup against hardware failure."
rm -rf "$STAGE"
