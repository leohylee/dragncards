# Local Setup Guide for DragnCards + MarvelsDB

This guide explains how to run DragnCards and MarvelsDB locally for Marvel Champions gameplay.

## Prerequisites

- Docker Desktop installed and running
- Node.js 20.x (via nvm)
- PHP 7.4

## 1. Starting DragnCards

### Backend (Docker - Postgres + Elixir/Phoenix)

Start the backend services (PostgreSQL database + Phoenix server) using Docker Compose:

```bash
cd /Users/leo/Projects/dragncards
docker compose up -d
```

This starts:
- **PostgreSQL** on port 5432
- **Backend (Phoenix)** on port 4000

Wait about 30 seconds for the backend to fully start and run migrations.

Check logs if needed:
```bash
docker compose logs -f backend
```

### Frontend (Local Node.js)

The frontend runs outside Docker due to Node.js/webpack OpenSSL compatibility issues:

```bash
cd /Users/leo/Projects/dragncards/frontend
nvm use 20
NODE_OPTIONS="--openssl-legacy-provider" npm start
```

The frontend will be available at `http://localhost:3000`

**Note:** The frontend must use Node 20 with the legacy OpenSSL provider flag due to webpack compatibility.

## 2. Starting MarvelsDB

### Start MySQL Database

```bash
cd /Users/leo/Projects/marvelsdb
docker-compose up -d
```

This starts MySQL 8.0 on port 3307 with:
- Database: `marvelsdb`
- User: `marvelsdb`
- Password: `marvelsdb`

### Start PHP Web Server

```bash
cd /Users/leo/Projects/marvelsdb
php bin/console server:run 0.0.0.0:8000
```

MarvelsDB will be available at `http://localhost:8000`

### Login Credentials

- **Username:** admin
- **Password:** password123

## 3. Importing Decks from MarvelsDB to DragnCards

1. **Create a deck in MarvelsDB:**
   - Go to http://localhost:8000
   - Login with the credentials above
   - Create a new deck
   - Publish it as a decklist (description is optional)
   - Copy the decklist URL (e.g., `http://localhost:8000/decklist/view/1/spider-man-1.0`)

2. **Import in DragnCards:**
   - Open DragnCards at http://localhost:3000
   - Create or join a Marvel Champions game room
   - Click the menu → Import → Load via URL
   - Paste your localhost MarvelsDB URL
   - The deck will be imported into your play area

## 4. Available Features

### DragnCards

- **Local card images:** All 3,569 Marvel Champions card images are hosted locally at `/frontend/public/mc-cards/official/`
- **Pre-built decks:** 457 hero decks, scenarios, modular sets available
- **Replay download:** Full replay JSON download enabled (Patreon check disabled for local use)
- **Import support:** Import decks from both marvelcdb.com and localhost:8000

### MarvelsDB

- **Full card database:** 3,746 cards (94.6% have images)
- **Deck builder:** Create and validate Marvel Champions decks
- **Publishing:** Share decklists (24-hour restriction and description requirement disabled for local development)
- **API access:** Public API available at `http://localhost:8000/api/public/`

## 5. Stopping Services

### DragnCards

```bash
# Stop frontend
# Press Ctrl+C in the npm start terminal

# Stop backend and postgres
cd /Users/leo/Projects/dragncards
docker compose down
```

### MarvelsDB

```bash
# Stop PHP server
# Press Ctrl+C in the PHP server terminal

# Stop MySQL
cd /Users/leo/Projects/marvelsdb
docker-compose down
```

## 6. Troubleshooting

### DragnCards frontend won't start
- Make sure you're using Node 20: `nvm use 20`
- Include the OpenSSL flag: `NODE_OPTIONS="--openssl-legacy-provider" npm start`

### MarvelsDB images not showing
- Card images are symlinked from DragnCards at `/Users/leo/Projects/dragncards/frontend/public/mc-cards/official/`
- Both `.jpg` and `.png` symlinks should exist in `/Users/leo/Projects/marvelsdb/web/bundles/cards/`

### Deck import fails
- Ensure both DragnCards frontend and MarvelsDB are running
- Check that the decklist is published (not just saved as a private deck)
- Verify the URL format: `http://localhost:8000/decklist/view/[ID]/[name]`

### Database connection issues
- Verify MySQL Docker container is running: `docker ps | grep marvelsdb`
- Check connection settings in `/Users/leo/Projects/marvelsdb/app/config/parameters.yml`

## 7. Plugin Information

### Marvel Champions Plugin

- **Location:** `/Users/leo/Projects/dragncards/backend/priv/dragncards-mc-plugin/`
- **Cards:** 3,523 cards with marvelcdbId mappings
- **Images:** Stored at `/Users/leo/Projects/dragncards/frontend/public/mc-cards/official/`
- **Pre-built decks:** 457 decks in `preBuiltDecks.json`

### Lord of the Rings LCG Plugin

- **Location:** `/Users/leo/Projects/dragncards/backend/priv/dragncards-lotrlcg-plugin/`
- **Cards:** 4,376 cards
- **Images:** Stored at `/Users/leo/Projects/dragncards/frontend/public/lotrlcg-cards/`

## 8. Development Notes

### Modified Files for Local Development

**DragnCards:**
- `frontend/src/features/engine/hooks/useImportViaUrl.js` - Added localhost support for deck imports
- `frontend/src/features/engine/TopBarMenu.js` - Disabled Patreon check for replay downloads

**MarvelsDB:**
- `src/AppBundle/Controller/SocialController.php` - Disabled description requirement and 24-hour publishing restriction
- `web/bundles/cards/` - Symlinks to DragnCards images

### Regenerating Card JSON

If you add new images to MarvelsDB, regenerate the card JSON files:

```bash
cd /Users/leo/Projects/marvelsdb
php -d memory_limit=512M bin/console app:static
```

This updates `/web/cards-player-en.json` and `/web/cards-all-en.json` with image paths for tooltips.

---

**Last Updated:** October 14, 2025
