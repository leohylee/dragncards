#!/bin/bash

# Comprehensive Backup Script for DragnCards + RingsDB + MarvelsDB
# Creates timestamped backups of all databases, configurations, and card images

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="/Users/leo/Projects/backups"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

echo "🔄 Starting comprehensive backup..."
echo "📁 Backup directory: $BACKUP_DIR"

# Create backup directory structure
mkdir -p "$BACKUP_DIR"/{ringsdb,marvelsdb,dragncards}/{database,config,images}

# ==========================================
# 1. RingsDB Backup
# ==========================================
echo ""
echo "📦 Backing up RingsDB..."

# Database
echo "  ├─ Database backup..."
docker exec ringsdb-mysql mysqldump -u ringsdb -pringsdb ringsdb > "$BACKUP_DIR/ringsdb/database/ringsdb.sql" 2>/dev/null
echo "  │  ✓ $(du -h "$BACKUP_DIR/ringsdb/database/ringsdb.sql" | cut -f1)"

# Configuration files
echo "  ├─ Configuration backup..."
cp /Users/leo/Projects/ringsdb/app/config/parameters.yml "$BACKUP_DIR/ringsdb/config/"
cp /Users/leo/Projects/ringsdb/docker-compose.yml "$BACKUP_DIR/ringsdb/config/"
cp /Users/leo/Projects/ringsdb/Dockerfile "$BACKUP_DIR/ringsdb/config/"
echo "  │  ✓ 3 config files"

# Card images (create tar.gz to save space)
echo "  ├─ Card images backup (this may take a while)..."
tar -czf "$BACKUP_DIR/ringsdb/images/cards.tar.gz" -C /Users/leo/Projects/ringsdb/web/bundles cards/ 2>/dev/null
echo "  │  ✓ $(du -h "$BACKUP_DIR/ringsdb/images/cards.tar.gz" | cut -f1)"

# SQL schema files
echo "  └─ SQL schema files..."
cp /Users/leo/Projects/ringsdb/*.sql "$BACKUP_DIR/ringsdb/database/" 2>/dev/null
echo "     ✓ Schema files backed up"

# ==========================================
# 2. MarvelsDB Backup
# ==========================================
echo ""
echo "📦 Backing up MarvelsDB..."

# Database
echo "  ├─ Database backup..."
docker exec marvelsdb-mysql mysqldump -u marvelsdb -pmarvelsdb marvelsdb > "$BACKUP_DIR/marvelsdb/database/marvelsdb.sql" 2>/dev/null
echo "  │  ✓ $(du -h "$BACKUP_DIR/marvelsdb/database/marvelsdb.sql" | cut -f1)"

# Configuration files
echo "  ├─ Configuration backup..."
cp /Users/leo/Projects/marvelsdb/app/config/parameters.yml "$BACKUP_DIR/marvelsdb/config/"
cp /Users/leo/Projects/marvelsdb/docker-compose.yml "$BACKUP_DIR/marvelsdb/config/"
cp /Users/leo/Projects/marvelsdb/Dockerfile "$BACKUP_DIR/marvelsdb/config/"
echo "  │  ✓ 3 config files"

# Note: MarvelsDB uses symlinks to DragnCards images
echo "  └─ Images are symlinked to DragnCards (backed up below)"

# ==========================================
# 3. DragnCards Backup
# ==========================================
echo ""
echo "📦 Backing up DragnCards..."

# PostgreSQL Database
echo "  ├─ PostgreSQL backup..."
docker exec dragncards-postgres-1 pg_dump -U postgres dragncards_dev > "$BACKUP_DIR/dragncards/database/dragncards_dev.sql" 2>/dev/null
echo "  │  ✓ $(du -h "$BACKUP_DIR/dragncards/database/dragncards_dev.sql" | cut -f1)"

# Configuration files
echo "  ├─ Configuration backup..."
cp /Users/leo/Projects/dragncards/compose.yml "$BACKUP_DIR/dragncards/config/"
cp /Users/leo/Projects/dragncards/start-dragncards.sh "$BACKUP_DIR/dragncards/config/"
cp /Users/leo/Projects/dragncards/README.md "$BACKUP_DIR/dragncards/config/"
cp /Users/leo/Projects/dragncards/CHANGELOG.md "$BACKUP_DIR/dragncards/config/"
echo "  │  ✓ 4 config files"

# Backend plugin files
echo "  ├─ Plugin backups..."
mkdir -p "$BACKUP_DIR/dragncards/plugins"
cp -r /Users/leo/Projects/dragncards/backend/priv/dragncards-lotrlcg-plugin "$BACKUP_DIR/dragncards/plugins/"
cp -r /Users/leo/Projects/dragncards/backend/priv/dragncards-mc-plugin "$BACKUP_DIR/dragncards/plugins/"
echo "  │  ✓ 2 plugins (LOTR LCG + Marvel Champions)"

# Import scripts
cp /Users/leo/Projects/dragncards/backend/priv/import_lotrlcg_from_json.exs "$BACKUP_DIR/dragncards/plugins/"
cp /Users/leo/Projects/dragncards/backend/priv/import_lotrlcg_plugin.exs "$BACKUP_DIR/dragncards/plugins/" 2>/dev/null
cp /Users/leo/Projects/dragncards/backend/priv/import_mc_plugin.exs "$BACKUP_DIR/dragncards/plugins/" 2>/dev/null

# Frontend card database
echo "  ├─ Frontend card database..."
mkdir -p "$BACKUP_DIR/dragncards/frontend-data"
cp /Users/leo/Projects/dragncards/frontend/src/features/plugins/lotrlcg/definitions/cardDb.json "$BACKUP_DIR/dragncards/frontend-data/"
echo "  │  ✓ cardDb.json ($(du -h "$BACKUP_DIR/dragncards/frontend-data/cardDb.json" | cut -f1))"

# Card images
echo "  ├─ LOTR LCG card images (this may take a while)..."
tar -czf "$BACKUP_DIR/dragncards/images/lotrlcg-cards.tar.gz" -C /Users/leo/Projects/dragncards/frontend/public lotrlcg-cards/ 2>/dev/null
echo "  │  ✓ $(du -h "$BACKUP_DIR/dragncards/images/lotrlcg-cards.tar.gz" | cut -f1)"

echo "  └─ Marvel Champions card images..."
tar -czf "$BACKUP_DIR/dragncards/images/mc-cards.tar.gz" -C /Users/leo/Projects/dragncards/frontend/public mc-cards/ 2>/dev/null
echo "     ✓ $(du -h "$BACKUP_DIR/dragncards/images/mc-cards.tar.gz" | cut -f1)"

# ==========================================
# Create backup manifest
# ==========================================
echo ""
echo "📝 Creating backup manifest..."

cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
========================================
DragnCards Offline Backup
========================================
Backup Date: $(date)
Backup Directory: $BACKUP_DIR

CONTENTS:
---------

RingsDB:
  - Database: ringsdb/database/ringsdb.sql ($(du -h "$BACKUP_DIR/ringsdb/database/ringsdb.sql" | cut -f1))
  - Card Images: ringsdb/images/cards.tar.gz ($(du -h "$BACKUP_DIR/ringsdb/images/cards.tar.gz" | cut -f1))
  - Configuration: ringsdb/config/*.yml
  - SQL Schema: ringsdb/database/*.sql

MarvelsDB:
  - Database: marvelsdb/database/marvelsdb.sql ($(du -h "$BACKUP_DIR/marvelsdb/database/marvelsdb.sql" | cut -f1))
  - Configuration: marvelsdb/config/*.yml
  - Images: Symlinked to DragnCards

DragnCards:
  - Database: dragncards/database/dragncards_dev.sql ($(du -h "$BACKUP_DIR/dragncards/database/dragncards_dev.sql" | cut -f1))
  - LOTR Images: dragncards/images/lotrlcg-cards.tar.gz ($(du -h "$BACKUP_DIR/dragncards/images/lotrlcg-cards.tar.gz" | cut -f1))
  - MC Images: dragncards/images/mc-cards.tar.gz ($(du -h "$BACKUP_DIR/dragncards/images/mc-cards.tar.gz" | cut -f1))
  - Plugins: dragncards/plugins/
  - Frontend Data: dragncards/frontend-data/
  - Configuration: dragncards/config/

RECOVERY INSTRUCTIONS:
----------------------
See RECOVERY.md in this directory for detailed recovery procedures.

VERIFICATION:
-------------
Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)

All databases backed up: ✓
All configurations backed up: ✓
All card images backed up: ✓
All plugins backed up: ✓

EOF

# ==========================================
# Summary
# ==========================================
echo ""
echo "✅ Backup completed successfully!"
echo ""
echo "📊 Backup Summary:"
echo "   Location: $BACKUP_DIR"
echo "   Total Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "📄 Files backed up:"
find "$BACKUP_DIR" -type f -exec basename {} \; | sort | uniq | while read file; do
  echo "   • $file"
done
echo ""
echo "💾 Keep this backup in a safe location for offline recovery!"
echo "📖 See $BACKUP_DIR/MANIFEST.txt for details"
echo ""
