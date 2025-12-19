# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [Local Setup - 2025-10-17]

### Added

#### LOTR LCG Plugin v10
- Fixed card flip function - cards now properly show card backs when flipped
- Updated card structure to preserve nested `sides.A` and `sides.B` format
- Added support for 266 ALeP (fan-made) cards (up from 255)
- Total cards: 5,169 with 5,355 card images (~1.2 GB)

#### Docker Configuration
- Added complete Docker Compose setup for frontend, backend, and postgres
- Created `start-dragncards.sh` one-command startup script
- Frontend now runs in Docker with Node.js 20 and `--legacy-peer-deps` flag
- All three services (frontend, backend, postgres) can run with single command

#### Database Backups
- Created RingsDB backup: `ringsdb_backup.sql` (795 KB)
- Created MarvelsDB backup: `marvelsdb_backup.sql` (3.0 MB)
- Complete database dumps include all cards, packs, sets, and structure

#### RingsDB Integration
- Local RingsDB instance on port 8001
- Complete card database with 1,486 cards including 266 ALeP cards
- 32 cycles, 114+ packs properly organized
- 1.8 GB of card images stored locally
- Character encoding fixed (UTF-8 support for É, ó, û)
- Deck import from localhost:8001 to DragnCards

#### MarvelsDB Integration
- Local MarvelsDB instance on port 8000
- Full card database with 3,746+ cards
- Deck builder with validation
- Deck import from localhost:8000 to DragnCards
- Admin account: admin/password123

#### Offline-Proof Configuration
- **Zero external dependencies** - All three services work completely offline
- **Local card images** - 9+ GB of card images stored locally (5,355 LOTR + 3,569 MC)
- Changed Marvel Champions `imageUrlPrefix` to use `/mc-cards` instead of `http://localhost:3000/mc-cards`
- LOTR LCG already using `/lotrlcg-cards/` (relative path)
- **No CDN dependencies** - No external fonts, scripts, or stylesheets required
- **Self-contained** - All plugins, card data, and images bundled locally
- **Complete offline gameplay** - Works with no internet connection once containers running

#### Comprehensive Backup & Recovery System
- Created `backup-all.sh` - Automated backup script for all three services
- Created `restore-all.sh` - One-command restore from backup
- Created `RECOVERY.md` - Detailed recovery documentation for corrupted data
- **Timestamped backups** - Each backup stored in `{projectDir}/backups/backup_YYYYMMDD_HHMMSS/`
- **Compressed archives** - Card images compressed with tar.gz (~4-5 GB total)
- **Complete manifests** - Each backup includes MANIFEST.txt with contents and verification
- **Partial recovery** - Can restore individual components (databases, images, configs, plugins)
- **Verification** - Automatic verification after restore with card counts and service checks
- **Offline recovery** - All backups self-contained for complete offline restore capability

### Changed

#### Card Structure Compatibility
- Backend `card.ex` - Handle both nested and flat card structures
- Backend `OBJ_GET_BY_PATH.ex` - Support both card structure formats
- Frontend hooks (`useVisibleFace`, `useCurrentFace`) - Support both formats
- Frontend `evaluate.js` - Handle both structures in evaluation logic
- Frontend `common.js` and `StackDraggable.js` - Support both formats
- Import script preserves `sides.A`/`sides.B` structure (no flattening)

#### Import Functionality
- `useImportViaUrl.js` - Added null check for cancelled prompts
- `useImportViaUrl.js` - Added localhost support for RingsDB and MarvelsDB
- `TopBarMenu.js` - Disabled Patreon check for local replay downloads

#### Documentation
- Merged `LOCAL_SETUP_GUIDE.md` into `README.md`
- Added comprehensive setup instructions for all three services
- Added troubleshooting section with common issues
- Added database backup and restore procedures
- Documented all modified files and changes

### Fixed

#### Card Flip Function (Plugin v10)
- **Issue:** Cards were not visually flipping to show card backs
- **Root cause:** Import script was flattening card structure from `sides.A` to flat `A`, but frontend expected nested structure
- **Fix:** Updated import script to preserve nested `sides.A` and `sides.B` structure
- **Fix:** Side B no longer gets `imageUrl` field - uses card backs instead
- **Result:** Cards now properly display player/encounter card backs when flipped

#### Backend Evaluation Errors
- Fixed `OBJ_GET_BY_PATH.ex` to handle both card structures when accessing `currentFace`
- Added fallback logic for cards with empty or invalid `sides` field
- Prevents "Tried to access side A on an object with sides []" errors

#### Frontend Display Issues
- Fixed hooks to handle both nested and flat card structures
- Prevents crashes when loading old games with flat structure
- Maintains compatibility with new games using nested structure

### Technical Details

**Plugin Versions:**
- LOTR LCG Plugin: v5 → v6 → v7 → v8 → v9 → v10

**Files Modified:**
- Backend: `card.ex`, `OBJ_GET_BY_PATH.ex`, `import_lotrlcg_from_json.exs`
- Frontend: `useVisibleFace.js`, `useCurrentFace.js`, `evaluate.js`, `common.js`, `StackDraggable.js`, `useImportViaUrl.js`
- Docker: `compose.yml`, `start-dragncards.sh`
- Documentation: `README.md`, `CHANGELOG.md`

**Card Counts:**
- LOTR LCG: 5,169 cards (including 266 ALeP)
- LOTR LCG Images: 5,355 files (~1.2 GB)
- Marvel Champions: 3,523 cards
- Marvel Champions Images: 3,569 files

**Services:**
- RingsDB: http://localhost:8001 (MySQL 8.0, PHP 7.4, Apache)
- MarvelsDB: http://localhost:8000 (MySQL 8.0, PHP 7.4, Apache)
- DragnCards Backend: http://localhost:4000 (Phoenix/Elixir, PostgreSQL)
- DragnCards Frontend: http://localhost:3000 (React, Node.js 20)

---

## [0.3.4] - 2020-03-16

### Changed

- Dependency updates

## [0.3.3] - 2020-01-26

### Changed

- Moved from `yarn` to `npm`.

## [0.3.2] - 2020-01-20

### Changed

- Dependency upgrades

## [0.3.1] - 2020-01-09

### Changed

- Moved chat layouts to be side-by-side with the game and lobby.

## [0.3.0] - 2019-11-22

### Added

- Bots learned how to bid by looking at their hands.
- Bots learned how to pick cards with some logic instead of randomly. They
  don't play perfectly, but they play "good enough" and are aware of nils.
  Note that they don't try to avoid bags.

## [0.2.1] - 2019-11-19

### Added

- Chat windows in the lobby and game rooms. Overall page layout needs to be
  improved, though.

## [0.2.0] - 2019-11-18

### Added

- Dumb bots to play against. They will always bid 3 and play random cards.

## [0.1.1] - 2019-11-17

### Fixed

- Fixed idle rooms not automatically deleting.

## [0.1.0] - 2019-11-16

Initial release. Rough, but playable with 4 people.

[unreleased]: https://github.com/seastan/dragncards/compare/HEAD
