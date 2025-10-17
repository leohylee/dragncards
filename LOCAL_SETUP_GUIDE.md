# Local Setup Guide for DragnCards + RingsDB + MarvelsDB

This guide explains how to run DragnCards, RingsDB, and MarvelsDB locally for Lord of the Rings LCG and Marvel Champions gameplay.

## Prerequisites

- Docker Desktop installed and running
- Node.js 20.x (via nvm)

## Quick Start

### 1. RingsDB (Lord of the Rings LCG)

**One-command startup:**

```bash
cd /Users/leo/Projects/ringsdb
docker-compose up -d
```

**Or use the startup script:**

```bash
cd /Users/leo/Projects/ringsdb
./start-ringsdb.sh
```

**Access:** http://localhost:8001

**What runs:**
- MySQL 8.0 on port 3308
- PHP 7.4 + Apache web server on port 8001
- All 1,486 cards with data
- 32 cycles, 114+ packs properly organized
- 1.8 GB of card images (locally stored)

---

### 2. MarvelsDB (Marvel Champions)

**One-command startup:**

```bash
cd /Users/leo/Projects/marvelsdb
docker-compose up -d
```

**Or use the startup script:**

```bash
cd /Users/leo/Projects/marvelsdb
./start-marvelsdb.sh
```

**Access:** http://localhost:8000

**What runs:**
- MySQL 8.0 on port 3307
- PHP 7.4 + Apache web server on port 8000
- Full card database with 3,746+ cards
- Card images (symlinked from DragnCards)

**Login Credentials:**
- **Username:** admin
- **Password:** password123

---

### 3. DragnCards (Game Client)

#### Option 1: Docker (Recommended - All-in-One)

**One-command startup:**

```bash
cd /Users/leo/Projects/dragncards
docker-compose up -d
```

**Or use the startup script:**

```bash
/Users/leo/Projects/dragncards/start-dragncards.sh
```

This starts:
- **PostgreSQL** on port 5432
- **Backend (Phoenix/Elixir)** on port 4000
- **Frontend (Node.js/React)** on port 3000

**Access:** http://localhost:3000

**Note:** First compilation may take 10-30 minutes due to large card database files. Subsequent starts are much faster.

**To view logs:**
```bash
docker-compose logs -f frontend  # Frontend logs
docker-compose logs -f backend   # Backend logs
```

**To stop:**
```bash
cd /Users/leo/Projects/dragncards
docker-compose down
```

#### Option 2: Manual Start (Alternative)

If you prefer running frontend locally for faster hot-reload:

**Backend:**
```bash
cd /Users/leo/Projects/dragncards
docker compose up -d backend postgres
```

**Frontend:**
```bash
cd /Users/leo/Projects/dragncards/frontend
export NODE_OPTIONS=--openssl-legacy-provider
npm start
```

---

## Importing Decks

### From RingsDB to DragnCards

1. **Create a deck in RingsDB:**
   - Go to http://localhost:8001
   - Build or browse a deck
   - Copy the deck URL (e.g., `http://localhost:8001/decklist/view/123/deck-name`)

2. **Import in DragnCards:**
   - Open DragnCards at http://localhost:3000
   - Create or join a Lord of the Rings LCG game room
   - Click menu → Import → Load via URL
   - Paste your localhost RingsDB URL
   - The deck will be imported (including ALeP cards!)

### From MarvelsDB to DragnCards

1. **Create a deck in MarvelsDB:**
   - Go to http://localhost:8000
   - Login with admin credentials
   - Create and publish a decklist
   - Copy the decklist URL (e.g., `http://localhost:8000/decklist/view/1/spider-man`)

2. **Import in DragnCards:**
   - Open DragnCards at http://localhost:3000
   - Create or join a Marvel Champions game room
   - Click menu → Import → Load via URL
   - Paste your localhost MarvelsDB URL
   - The deck will be imported into your play area

---

## Available Features

### RingsDB
- **Complete card database:** All 1,486 cards including ALeP (fan-made expansions)
- **32 cycles with proper organization:** Core Set through ALeP - Fell Summer
- **1.8 GB card images:** All stored locally on your Mac
- **Character encoding fixed:** Displays É, ó, û correctly
- **API access:** `http://localhost:8001/api/public/`

### MarvelsDB
- **Full card database:** 3,746+ cards (94.6% have images)
- **Deck builder:** Create and validate Marvel Champions decks
- **Publishing:** Share decklists (restrictions disabled for local development)
- **API access:** `http://localhost:8000/api/public/`

### DragnCards
- **Local card images:**
  - Marvel Champions: 3,569 images at `/frontend/public/mc-cards/official/`
  - LOTR LCG: Card images at `/frontend/public/lotrlcg-cards/`
- **Pre-built decks:** 457 hero decks, scenarios, modular sets
- **Replay download:** Full replay JSON download (Patreon check disabled locally)
- **Import support:**
  - Import from localhost:8001 (RingsDB)
  - Import from localhost:8000 (MarvelsDB)
  - Import from marvelcdb.com and ringsdb.com
- **ALeP card support:** All 255 ALeP cards included in card database

---

## Stopping Services

### RingsDB

```bash
cd /Users/leo/Projects/ringsdb
docker-compose down
```

### MarvelsDB

```bash
cd /Users/leo/Projects/marvelsdb
docker-compose down
```

### DragnCards

```bash
# Stop frontend (Press Ctrl+C in the npm start terminal)

# Stop backend
cd /Users/leo/Projects/dragncards
docker compose down
```

---

## Data Persistence

All data persists even when containers are stopped:

### RingsDB
- **Database:** Docker volume `ringsdb_data`
- **Card images:** `/Users/leo/Projects/ringsdb/web/bundles/cards/` (1.8 GB)
- **Database backup:** `/tmp/ringsdb_backup_20251016.sql` (794 KB)

### MarvelsDB
- **Database:** Docker volume `marvelsdb-data`
- **Card images:** Symlinked from DragnCards

### DragnCards
- **Database:** Docker volume `dragncards_postgres`
- **Card images:** `/Users/leo/Projects/dragncards/frontend/public/`

---

## Troubleshooting

### DragnCards frontend won't start
- Make sure you're using Node 20: `nvm use 20`
- Include the OpenSSL flag: `export NODE_OPTIONS=--openssl-legacy-provider`
- First compilation takes 10-30 minutes - be patient
- Check terminal for any errors

### RingsDB/MarvelsDB not accessible
- Verify Docker containers are running: `docker ps`
- Check logs: `docker-compose logs -f web`
- Make sure ports aren't already in use

### Deck import fails
- Ensure all services are running (backend + frontend + database)
- Check that the decklist is published (not private)
- Verify the URL format matches examples above
- For RingsDB: Enable link sharing in profile settings

### Card images not showing

**RingsDB:**
- Images at `/Users/leo/Projects/ringsdb/web/bundles/cards/`
- Should have 6,839 PNG/JPG files (1.8 GB)

**MarvelsDB:**
- Images symlinked from DragnCards
- Check symlinks exist in `/Users/leo/Projects/marvelsdb/web/bundles/cards/`

### Database recovery

**RingsDB backup/restore:**
```bash
# Backup
docker exec ringsdb-mysql mysqldump -u ringsdb -pringsdb ringsdb > backup.sql

# Restore
docker exec -i ringsdb-mysql mysql -u ringsdb -pringsdb ringsdb < backup.sql
```

**MarvelsDB backup/restore:**
```bash
# Backup
docker exec marvelsdb-mysql mysqldump -u marvelsdb -pmarvelsdb marvelsdb > backup.sql

# Restore
docker exec -i marvelsdb-mysql mysql -u marvelsdb -pmarvelsdb marvelsdb < backup.sql
```

---

## Plugin Information

### Lord of the Rings LCG Plugin

- **Location:** `/Users/leo/Projects/dragncards/backend/priv/dragncards-lotrlcg-plugin/`
- **Card database:** `/frontend/src/features/plugins/lotrlcg/definitions/cardDb.json`
- **Cards:** 5,286 cards (including 255 ALeP cards)
- **Images:** `/frontend/public/lotrlcg-cards/`
- **Import support:** localhost:8001 (RingsDB) and ringsdb.com

### Marvel Champions Plugin

- **Location:** `/Users/leo/Projects/dragncards/backend/priv/dragncards-mc-plugin/`
- **Cards:** 3,523 cards with marvelcdbId mappings
- **Images:** `/frontend/public/mc-cards/official/`
- **Pre-built decks:** 457 decks in `preBuiltDecks.json`
- **Import support:** localhost:8000 (MarvelsDB) and marvelcdb.com

---

## Development Notes

### Modified Files for Local Development

**DragnCards:**
- `frontend/src/features/engine/hooks/useImportViaUrl.js` - Added localhost support for RingsDB and MarvelsDB
- `frontend/src/features/engine/TopBarMenu.js` - Disabled Patreon check for replay downloads
- `frontend/src/features/plugins/lotrlcg/definitions/cardDb.json` - Added 255 ALeP cards (5,031 → 5,286 total)

**RingsDB:**
- `docker-compose.yml` - Full Docker setup with web service
- `Dockerfile` - PHP 7.3 + Apache configuration
- `app/config/parameters.yml` - Database connection configured for Docker
- Database: All 32 cycles and 114+ packs properly organized
- Database: Character encoding fixed (UTF-8)

**MarvelsDB:**
- `docker-compose.yml` - Full Docker setup with web service
- `Dockerfile` - PHP 7.4 + Apache configuration
- `app/config/parameters.yml` - Database connection configured for Docker
- `src/AppBundle/Controller/SocialController.php` - Disabled restrictions for local development
- `web/bundles/cards/` - Symlinks to DragnCards images

### Regenerating Card JSON (MarvelsDB)

If you add new images to MarvelsDB, regenerate the card JSON files:

```bash
cd /Users/leo/Projects/marvelsdb
php -d memory_limit=512M bin/console app:static
```

This updates `/web/cards-player-en.json` and `/web/cards-all-en.json` with image paths for tooltips.

---

## Summary

| Service | URL | Startup | Status |
|---------|-----|---------|--------|
| **RingsDB** | http://localhost:8001 | `docker-compose up -d` | ✅ One-click ready |
| **MarvelsDB** | http://localhost:8000 | `docker-compose up -d` | ✅ One-click ready |
| **DragnCards Backend** | http://localhost:4000 | `docker compose up -d` | ✅ One-click ready |
| **DragnCards Frontend** | http://localhost:3000 | `npm start` (with NODE_OPTIONS) | ⚠️ 10-30 min first compile |

---

**Last Updated:** October 17, 2025
