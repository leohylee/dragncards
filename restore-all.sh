#!/bin/bash

# Comprehensive Restore Script for DragnCards + RingsDB + MarvelsDB
# Restores from backup created by backup-all.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_directory>"
    echo "Example: $0 /Users/leo/Projects/backups/backup_20251017_180000"
    echo ""
    echo "Available backups:"
    ls -lt /Users/leo/Projects/backups/ | grep ^d | head -5
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Error: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo "🔄 Starting comprehensive restore from backup..."
echo "📁 Backup directory: $BACKUP_DIR"
echo ""
read -p "⚠️  This will OVERWRITE existing data. Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Restore cancelled."
    exit 0
fi

# ==========================================
# 1. RingsDB Restore
# ==========================================
echo ""
echo "📦 Restoring RingsDB..."

cd /Users/leo/Projects/ringsdb
docker-compose down

echo "  ├─ Starting MySQL..."
docker-compose up -d mysql
sleep 10

echo "  ├─ Restoring database..."
docker exec -i ringsdb-mysql mysql -u ringsdb -pringsdb ringsdb < "$BACKUP_DIR/ringsdb/database/ringsdb.sql" 2>/dev/null
echo "  │  ✓ Database restored"

echo "  ├─ Restoring card images..."
rm -rf web/bundles/cards
tar -xzf "$BACKUP_DIR/ringsdb/images/cards.tar.gz" -C web/bundles/
echo "  │  ✓ $(ls web/bundles/cards/ | wc -l | tr -d ' ') images restored"

echo "  └─ Starting web service..."
docker-compose up -d
echo "     ✓ RingsDB online at http://localhost:8001"

# ==========================================
# 2. MarvelsDB Restore
# ==========================================
echo ""
echo "📦 Restoring MarvelsDB..."

cd /Users/leo/Projects/marvelsdb
docker-compose down

echo "  ├─ Starting MySQL..."
docker-compose up -d mysql
sleep 10

echo "  ├─ Restoring database..."
docker exec -i marvelsdb-mysql mysql -u marvelsdb -pmarvelsdb marvelsdb < "$BACKUP_DIR/marvelsdb/database/marvelsdb.sql" 2>/dev/null
echo "  │  ✓ Database restored"

echo "  └─ Starting web service..."
docker-compose up -d
echo "     ✓ MarvelsDB online at http://localhost:8000"

# ==========================================
# 3. DragnCards Restore
# ==========================================
echo ""
echo "📦 Restoring DragnCards..."

cd /Users/leo/Projects/dragncards
docker-compose down

echo "  ├─ Starting PostgreSQL..."
docker-compose up -d postgres
sleep 5

echo "  ├─ Restoring database..."
docker exec -i dragncards-postgres-1 psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS dragncards_dev;" 2>/dev/null
docker exec -i dragncards-postgres-1 psql -U postgres -d postgres -c "CREATE DATABASE dragncards_dev;" 2>/dev/null
docker exec -i dragncards-postgres-1 psql -U postgres dragncards_dev < "$BACKUP_DIR/dragncards/database/dragncards_dev.sql" 2>/dev/null
echo "  │  ✓ Database restored"

echo "  ├─ Restoring LOTR card images..."
rm -rf frontend/public/lotrlcg-cards
tar -xzf "$BACKUP_DIR/dragncards/images/lotrlcg-cards.tar.gz" -C frontend/public/
echo "  │  ✓ $(ls frontend/public/lotrlcg-cards/ | wc -l | tr -d ' ') images restored"

echo "  ├─ Restoring Marvel Champions images..."
rm -rf frontend/public/mc-cards
tar -xzf "$BACKUP_DIR/dragncards/images/mc-cards.tar.gz" -C frontend/public/
echo "  │  ✓ $(find frontend/public/mc-cards/ -type f | wc -l | tr -d ' ') images restored"

echo "  ├─ Restoring plugins..."
cp -r "$BACKUP_DIR/dragncards/plugins/dragncards-lotrlcg-plugin" backend/priv/
cp -r "$BACKUP_DIR/dragncards/plugins/dragncards-mc-plugin" backend/priv/
echo "  │  ✓ Plugins restored"

echo "  ├─ Restoring frontend card database..."
cp "$BACKUP_DIR/dragncards/frontend-data/cardDb.json" frontend/src/features/plugins/lotrlcg/definitions/
echo "  │  ✓ cardDb.json restored"

echo "  └─ Starting all services..."
docker-compose up -d
echo "     ✓ DragnCards online:"
echo "       - Backend: http://localhost:4000"
echo "       - Frontend: http://localhost:3000"

# ==========================================
# Verification
# ==========================================
echo ""
echo "🔍 Verifying restoration..."
sleep 5

echo ""
echo "RingsDB:"
RINGSDB_CARDS=$(docker exec ringsdb-mysql mysql -u ringsdb -pringsdb -s -e "SELECT COUNT(*) FROM card;" ringsdb 2>/dev/null)
echo "  ✓ Cards in database: $RINGSDB_CARDS"

echo ""
echo "MarvelsDB:"
MARVELSDB_CARDS=$(docker exec marvelsdb-mysql mysql -u marvelsdb -pmarvelsdb -s -e "SELECT COUNT(*) FROM card;" marvelsdb 2>/dev/null)
echo "  ✓ Cards in database: $MARVELSDB_CARDS"

echo ""
echo "DragnCards:"
DRAGNCARDS_PLUGINS=$(docker exec dragncards-postgres-1 psql -U postgres dragncards_dev -t -c "SELECT COUNT(*) FROM plugins;" 2>/dev/null | tr -d ' ')
echo "  ✓ Plugins in database: $DRAGNCARDS_PLUGINS"

echo ""
echo "✅ Restore completed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "   - RingsDB: http://localhost:8001"
echo "   - MarvelsDB: http://localhost:8000"
echo "   - DragnCards: http://localhost:3000"
echo ""
echo "💡 Tip: Wait 1-2 minutes for DragnCards frontend to fully compile"
echo ""
