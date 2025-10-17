# DragnCards

Multiplayer online card game written in Elixir, Phoenix, React, and Typescript.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Local Development Setup](#local-development-setup)
  - [RingsDB](#1-ringsdb-lord-of-the-rings-lcg)
  - [MarvelsDB](#2-marvelsdb-marvel-champions)
  - [DragnCards](#3-dragncards-game-client)
- [Importing Decks](#importing-decks)
- [Available Features](#available-features)
- [Data Persistence & Backups](#data-persistence--backups)
- [Troubleshooting](#troubleshooting)
- [Plugin Information](#plugin-information)
- [Development Notes](#development-notes)
- [Recent Updates](#recent-updates)

---

## Quick Start

### Prerequisites

- Docker Desktop installed and running
- Node.js 20.x (via nvm recommended for macOS)

### All Services Startup

```bash
# RingsDB (LOTR LCG)
cd {project_dir}/ringsdb && docker-compose up -d

# MarvelsDB (Marvel Champions)
cd {project_dir}/marvelsdb && docker-compose up -d

# DragnCards (Game Client)
cd {project_dir}/dragncards && docker-compose up -d
# Or use: ./start-dragncards.sh
```

**Access Points:**
- **RingsDB:** http://localhost:8001
- **MarvelsDB:** http://localhost:8000
- **DragnCards:** http://localhost:3000 (first compile: 10-30 min)

---

## Local Development Setup

### 1. RingsDB (Lord of the Rings LCG)

**One-command startup:**

```bash
cd {project_dir}/ringsdb
docker-compose up -d
```

**Access:** http://localhost:8001

**What runs:**
- MySQL 8.0 on port 3308
- PHP 7.4 + Apache web server on port 8001
- All 1,486 cards with data (including 266 ALeP cards)
- 32 cycles, 114+ packs properly organized
- 1.8 GB of card images (locally stored)

---

### 2. MarvelsDB (Marvel Champions)

**One-command startup:**

```bash
cd {project_dir}/marvelsdb
docker-compose up -d
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
cd {project_dir}/dragncards
docker-compose up -d
```

**Or use the startup script:**

```bash
{project_dir}/dragncards/start-dragncards.sh
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
cd {project_dir}/dragncards
docker-compose down
```

#### Option 2: Manual Start (Alternative for Faster Hot-Reload)

If you prefer running frontend locally for faster hot-reload:

**Backend:**
```bash
cd {project_dir}/dragncards
docker compose up -d backend postgres
```

**Frontend:**
```bash
cd {project_dir}/dragncards/frontend
export NODE_OPTIONS=--openssl-legacy-provider
npm start
```

#### Option 3: Legacy Docker Compose Setup

For reference, the original setup method:

```bash
docker compose up -d backend
# First time: create dev_user with password "password"
docker compose exec backend mix run /app/priv/create_user.exs

docker compose run --rm --service-ports frontend
```

Browse to `localhost:3000` and proceed with [plugin installation](https://github.com/seastan/dragncards/wiki/Plugin-Documentation)

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

## Offline-Proof Setup ✈️

All three services are fully offline-capable with **zero external dependencies**:

✅ **No Internet Required**
- All card images stored locally (9+ GB total)
- All card data in local databases
- No CDN dependencies (fonts, scripts, styles)
- No external API calls required
- Complete offline gameplay experience

✅ **Self-Contained**
- RingsDB: 1.8 GB of card images locally
- MarvelsDB: Images symlinked from DragnCards
- DragnCards: 5,355 LOTR + 3,569 MC images locally
- All plugins bundled in backend container
- Database backups for complete restore

✅ **Local-Only Paths**
- LOTR images: `/lotrlcg-cards/` (relative path)
- Marvel images: `/mc-cards/` (relative path)
- No `http://` or `https://` external dependencies
- Works completely offline once containers are running

---

## Available Features

### RingsDB
- **Complete card database:** All 1,486 cards including 266 ALeP (fan-made expansions)
- **32 cycles with proper organization:** Core Set through ALeP - Fell Summer
- **1.8 GB card images:** All stored locally on your Mac
- **Character encoding fixed:** Displays É, ó, û correctly
- **API access:** `http://localhost:8001/api/public/`
- **Database backup:** Complete backup available for restore
- **Offline-proof:** No external dependencies

### MarvelsDB
- **Full card database:** 3,746+ cards (94.6% have images)
- **Deck builder:** Create and validate Marvel Champions decks
- **Publishing:** Share decklists (restrictions disabled for local development)
- **API access:** `http://localhost:8000/api/public/`
- **Offline-proof:** No external dependencies

### DragnCards
- **Local card images:**
  - Marvel Champions: 3,569 images at `/frontend/public/mc-cards/official/`
  - LOTR LCG: 5,355 images at `/frontend/public/lotrlcg-cards/` (1.2 GB)
- **Pre-built decks:** 457 hero decks, scenarios, modular sets
- **Replay download:** Full replay JSON download (Patreon check disabled locally)
- **Import support:**
  - Import from localhost:8001 (RingsDB)
  - Import from localhost:8000 (MarvelsDB)
  - Import from marvelcdb.com and ringsdb.com (when online)
- **ALeP card support:** All 266 ALeP cards included in card database
- **Flip function:** Working correctly in plugin v10 - cards show proper card backs when flipped
- **Docker support:** Complete Docker Compose setup for all services
- **Offline-proof:** All images and data local - works with no internet connection

---

## Data Persistence & Backups

All data persists even when containers are stopped:

### RingsDB
- **Database:** Docker volume `ringsdb_data`
- **Card images:** `{project_dir}/ringsdb/web/bundles/cards/` (1.8 GB)
- **Database backup:** `{project_dir}/ringsdb/ringsdb_backup.sql` (795 KB)
- **Backup date:** 2025-10-17

### MarvelsDB
- **Database:** Docker volume `marvelsdb-data`
- **Card images:** Symlinked from DragnCards
- **Database backup:** `{project_dir}/marvelsdb/marvelsdb_backup.sql` (3.0 MB)
- **Backup date:** 2025-10-17

### DragnCards
- **Database:** Docker volume `dragncards_postgres` (via compose.yml)
- **Card images:** `{project_dir}/dragncards/frontend/public/`
- **LOTR LCG images:** 5,355 files (~1.2 GB)
- **Marvel Champions images:** 3,569 files

### Database Backup & Restore

**RingsDB:**
```bash
# Backup (already done on 2025-10-17)
cd {project_dir}/ringsdb
docker exec ringsdb-mysql mysqldump -u ringsdb -pringsdb ringsdb > ringsdb_backup.sql

# Restore from backup (restores all cards, packs, scenarios)
cd {project_dir}/ringsdb
docker exec -i ringsdb-mysql mysql -u ringsdb -pringsdb ringsdb < ringsdb_backup.sql
```

**MarvelsDB:**
```bash
# Backup (already done on 2025-10-17)
cd {project_dir}/marvelsdb
docker exec marvelsdb-mysql mysqldump -u marvelsdb -pmarvelsdb marvelsdb > marvelsdb_backup.sql

# Restore from backup (restores all cards, packs, sets, users, decks)
cd {project_dir}/marvelsdb
docker exec -i marvelsdb-mysql mysql -u marvelsdb -pmarvelsdb marvelsdb < marvelsdb_backup.sql
```

**Note:** These backups contain complete database dumps. Restore commands will import:
- All card data with full details
- All packs, expansions, and card sets
- User accounts and published decklists (MarvelsDB only)
- Database structure, indexes, and relations

---

## Stopping Services

### RingsDB

```bash
cd {project_dir}/ringsdb
docker-compose down
```

### MarvelsDB

```bash
cd {project_dir}/marvelsdb
docker-compose down
```

### DragnCards

```bash
cd {project_dir}/dragncards
docker-compose down
```

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
- Images at `{project_dir}/ringsdb/web/bundles/cards/`
- Should have 6,839 PNG/JPG files (1.8 GB)

**MarvelsDB:**
- Images symlinked from DragnCards
- Check symlinks exist in `{project_dir}/marvelsdb/web/bundles/cards/`

---

## Plugin Information

### Lord of the Rings LCG Plugin

- **Location:** `{project_dir}/dragncards/backend/priv/dragncards-lotrlcg-plugin/`
- **Card database:** `/frontend/src/features/plugins/lotrlcg/definitions/cardDb.json`
- **Cards:** 5,169 cards (including 266 ALeP cards)
- **Images:** `/frontend/public/lotrlcg-cards/` (5,355 files)
- **Plugin version:** 10 (latest)
- **Import support:** localhost:8001 (RingsDB) and ringsdb.com
- **Flip function:** Fixed in plugin v10 - cards now properly show face down when flipped

### Marvel Champions Plugin

- **Location:** `{project_dir}/dragncards/backend/priv/dragncards-mc-plugin/`
- **Cards:** 3,523 cards with marvelcdbId mappings
- **Images:** `/frontend/public/mc-cards/official/`
- **Pre-built decks:** 457 decks in `preBuiltDecks.json`
- **Import support:** localhost:8000 (MarvelsDB) and marvelcdb.com

---

## Development Notes

### Modified Files for Local Development

**DragnCards - Import & UI:**
- `frontend/src/features/engine/hooks/useImportViaUrl.js` - Added localhost support + null check for cancel
- `frontend/src/features/engine/TopBarMenu.js` - Disabled Patreon check for replay downloads
- `frontend/src/features/plugins/lotrlcg/definitions/cardDb.json` - Updated with 266 ALeP cards

**DragnCards - Card Flip Fix (v10):**
- `backend/priv/import_lotrlcg_from_json.exs` - Fixed to preserve nested `sides.A/B` structure
- `backend/lib/dragncards_game/card.ex` - Handle both nested and flat card structures
- `backend/lib/dragncards_game/evaluate/functions/OBJ_GET_BY_PATH.ex` - Support both structures
- `frontend/src/features/engine/hooks/useVisibleFace.js` - Support both structures
- `frontend/src/features/engine/hooks/useCurrentFace.js` - Support both structures
- `frontend/src/features/engine/hooks/evaluate.js` - Support both structures
- `frontend/src/features/engine/functions/common.js` - Support both structures
- `frontend/src/features/engine/StackDraggable.js` - Support both structures

**DragnCards - Docker:**
- `compose.yml` - Added frontend container with Node.js 20, fixed npm legacy-peer-deps
- `start-dragncards.sh` - One-command startup script for all services

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

### Optional Users (Legacy Setup)

If you need to create additional users with SQL:

| username| password |
|------|-----|
|player1@dragncards.com|password1|
|player2@dragncards.com |password2|
|player3@dragncards.com |password3|
|player4@dragncards.com |password4|

Run the following to create a `users.sql` file and then inject it:
```bash
cat > users.sql << EOF
      INSERT INTO users (email , alias, inserted_at, updated_at, password_hash, email_confirmed_at, email_confirmation_token )
      VALUES ('player1@dragncards.com', 'player1', 'now', 'now', '$pbkdf2-sha512$100000$lBo3zNe49wIoWrAvht6Mbg==$SDfV/L5fNapiox7OgAJNB5rwrUm9RRNPCUBLHKXnNoVHcu574up2Tquxaa6shenktv7sCOtUu6rh4q0CmtOR+w==', 'now', 'c236e80a-2c34-44b9-92ab-312df26365f9' );
      INSERT INTO users (id , email , alias, inserted_at, updated_at, password_hash, email_confirmed_at, email_confirmation_token )
      VALUES ('7', 'player2@dragncards.com', 'player2', 'now', 'now', '$pbkdf2-sha512$100000$Hiwfmqbz6R0/R/q3whjVnA==$BvGkKDB/YfRnU4aQcV6INNJ8gv25Quw7SgzG64H7By5EgRdlTXIsOVHcLk7+Lf+bPqLkejAbl4F8Aanl1tASPQ==', 'now', '6a35ba55-fd0d-47e5-aff1-d53edd5af1ec' );
      INSERT INTO users (id , email , alias, inserted_at, updated_at, password_hash, email_confirmed_at, email_confirmation_token )
      VALUES ('8', 'player3@dragncards.com', 'player3', 'now', 'now', '$pbkdf2-sha512$100000$Z0jyoOb1KfzCuTGh/xVrZA==$YAlsffctWUbxujs3woZGZO6KGW++LquQAmc9MRalCXqBhaJYiOxJFjkkRjMAtbwLziVxCFD/LiRGlHutGvSpzw==', 'now', '45eacb70-01c4-4194-a3b3-fe927bef0d0b' );
      INSERT INTO users (id , email , alias, inserted_at, updated_at, password_hash, email_confirmed_at, email_confirmation_token )
      VALUES ('9', 'player4@dragncards.com', 'player4', 'now', 'now', '$pbkdf2-sha512$100000$1pFAgFabRwWro2FoLewoXw==$z0RCI+KwM68hdCxX+z+pN0mKELAd8aqvuPy+XUxNNx/ebpxrxlrxZ1fvLZ7NJQKyZnoF89NoR3fIggAYOJmEGQ==', 'now', '9c05358a-5b4f-477a-a201-8565a842ec2f' );
EOF
sql -d dragncards_dev -f ./users.sql -U postgres -h 127.0.0.1
```

### Regenerating Card JSON (MarvelsDB)

If you add new images to MarvelsDB, regenerate the card JSON files:

```bash
cd {project_dir}/marvelsdb
php -d memory_limit=512M bin/console app:static
```

This updates `/web/cards-player-en.json` and `/web/cards-all-en.json` with image paths for tooltips.

### Version of Software

There can be challenges with any `snap` installations of `docker` and the bundled version of `compose`. As of time of commit the following versions were working:

```
docker version && docker compose version
Client: Docker Engine - Community
 Version:           27.3.1
 API version:       1.47
 Go version:        go1.22.7
 Git commit:        ce12230
 Built:             Fri Sep 20 11:41:08 2024
 OS/Arch:           linux/arm64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          27.3.1
  API version:      1.47 (minimum version 1.24)
  Go version:       go1.22.7
  Git commit:       41ca978
  Built:            Fri Sep 20 11:41:08 2024
  OS/Arch:          linux/arm64
  Experimental:     false
 containerd:
  Version:          1.7.22
  GitCommit:        7f7fdf5fed64eb6a7caf99b3e12efcf9d60e311c
 runc:
  Version:          1.1.14
  GitCommit:        v1.1.14-0-g2c9f560
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
Docker Compose version v2.29.7
```

---

## Recent Updates (October 17, 2025)

### Card Flip Function Fixed
- **Issue:** Cards were not flipping to show card backs
- **Root cause:** Import script was flattening card structure, frontend expected nested structure
- **Fix:** Updated import script to preserve `sides.A` and `sides.B` structure
- **Result:** Plugin v10 released - flip function now works correctly
- **Note:** Create new game rooms to use plugin v10 with proper flip functionality

### Database Backups Created
- **RingsDB:** Complete backup at `{project_dir}/ringsdb/ringsdb_backup.sql` (795 KB)
- **MarvelsDB:** Complete backup at `{project_dir}/marvelsdb/marvelsdb_backup.sql` (3.0 MB)
- Both backups include all cards, packs, and database structure

### Docker Configuration
- Frontend now runs in Docker alongside backend and postgres
- Added `start-dragncards.sh` for one-command startup
- Updated `compose.yml` with frontend service using Node.js 20
- Fixed npm dependencies with `--legacy-peer-deps` flag

---

## Summary

| Service | URL | Startup | Status |
|---------|-----|---------|--------|
| **RingsDB** | http://localhost:8001 | `docker-compose up -d` | ✅ One-click ready |
| **MarvelsDB** | http://localhost:8000 | `docker-compose up -d` | ✅ One-click ready |
| **DragnCards Backend** | http://localhost:4000 | `docker compose up -d` | ✅ One-click ready |
| **DragnCards Frontend** | http://localhost:3000 | `docker compose up -d` or `npm start` | ⚠️ 10-30 min first compile |

---

**Last Updated:** October 17, 2025
