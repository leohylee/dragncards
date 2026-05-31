#!/usr/bin/env python3
"""Sync DragnCards plugin resources from the authoritative live plugins to this fork.

Two "upstreams" exist for this fork:
  * CODE      -> git remote `upstream` (seastan/dragncards)   [reported, never auto-merged]
  * PLUGINS   -> the LIVE plugins on dragncards.com            [the real content/image source]
                  MC   = live id 2  (local id 8, name "Marvel Champions")
                  LOTR = live id 1  (local id 7, name "Lord of the Rings LCG")

Images are fetched from the canonical REMOTE CDNs (the live plugin's own
imageUrlPrefix), NOT from this fork's localized "/mc-cards" & "/lotrlcg-cards"
prefixes. New upstream art therefore lands in the local mirrors that the offline
config already serves from, and the offline config is never touched.

Subcommands
  report   [mc|lotr|all]            fetch live plugins, diff content + images vs local, print a summary
  images   [mc|lotr|all] [--apply]  list (or with --apply, download) images referenced by the live
                                     card_db that are missing from the local mirror
Common flags
  --refresh                 ignore the cached live-plugin JSON and refetch
  --retry-unavailable       re-attempt images previously recorded as 403/unavailable
  --workers N               parallel download workers (default 8)

Stdlib only (urllib). Safe to re-run; only missing images are downloaded.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
API = "https://dragncards.com/be/api/plugins/raw/{id}"
PG_CONTAINER = "dragncards-postgres-1"
PG_DB = "dragncards_dev"
CACHE_TTL = 6 * 3600  # refetch live JSON if older than this

PLUGINS = {
    "mc": {
        "live_id": 2,
        "local_name": "Marvel Champions",
        "mirror": REPO / "frontend/public/mc-cards",
        "fallback_prefix": "https://cerebrodatastorage.blob.core.windows.net/cerebro-cards",
        "plugin_dir": REPO / "backend/priv/dragncards-mc-plugin",
    },
    "lotr": {
        "live_id": 1,
        "local_name": "Lord of the Rings LCG",
        "mirror": REPO / "frontend/public/lotrlcg-cards",
        "fallback_prefix": "https://dragncards-lotrlcg.s3.amazonaws.com/cards/English/",
        "plugin_dir": REPO / "backend/priv/dragncards-lotrlcg-plugin",
    },
}


# ---------- HTTP ----------
def http_get(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": "dragncards-sync/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read(), 200
    except urllib.error.HTTPError as e:
        return None, e.code
    except Exception:
        return None, 0


def fetch_live(key, refresh=False):
    p = PLUGINS[key]
    cache = Path(tempfile.gettempdir()) / f"dragncards-live-{key}.json"
    if not refresh and cache.exists() and (time.time() - cache.stat().st_mtime) < CACHE_TTL:
        return json.loads(cache.read_text())
    print(f"  fetching live {key} (id {p['live_id']}) from dragncards.com ...", file=sys.stderr)
    body, code = http_get(API.format(id=p["live_id"]), timeout=120)
    if body is None:
        raise SystemExit(f"ERROR: could not fetch live plugin {key} (HTTP {code}). Are you online?")
    cache.write_bytes(body)
    return json.loads(body)


# ---------- image helpers ----------
def collect_image_urls(obj, out):
    """Recursively gather every string value stored under an 'imageUrl' key."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "imageUrl" and isinstance(v, str) and v:
                out.add(v)
            else:
                collect_image_urls(v, out)
    elif isinstance(obj, list):
        for v in obj:
            collect_image_urls(v, out)


def english_prefix(game_def, fallback):
    pref = (game_def or {}).get("imageUrlPrefix") or {}
    return pref.get("English") or pref.get("Default") or fallback


def remote_url(image_url, prefix):
    # Replicate the frontend: a full http url is used as-is, else prefix + suffix (literal concat).
    if image_url.startswith("http"):
        return image_url
    return prefix + image_url


def local_path(image_url, mirror):
    if image_url.startswith("http"):
        name = image_url.split("?")[0].rstrip("/").split("/")[-1]
        return mirror / name
    return mirror / image_url.lstrip("/")


def unavailable_file(mirror):
    return mirror / ".sync-unavailable.txt"


def load_unavailable(mirror):
    f = unavailable_file(mirror)
    return set(f.read_text().split()) if f.exists() else set()


def save_unavailable(mirror, names):
    if names:
        unavailable_file(mirror).write_text("\n".join(sorted(names)) + "\n")


# ---------- postgres (local) ----------
def psql(sql):
    try:
        out = subprocess.run(
            ["docker", "exec", PG_CONTAINER, "psql", "-U", "postgres", "-d", PG_DB, "-tAc", sql],
            capture_output=True, text=True, timeout=120,
        )
        if out.returncode != 0:
            return None
        return out.stdout
    except Exception:
        return None


def _lines(out):
    # jsonb_object_keys returns one key per line; keys (deck names) may contain
    # spaces, so split on newlines only -- never on whitespace.
    if not out:
        return set()
    return {ln.strip() for ln in out.splitlines() if ln.strip()}


def local_plugin_id(name):
    out = psql(f"SELECT id FROM plugins WHERE name = '{name}';")
    if out and out.strip():
        return int(out.strip().splitlines()[0])
    return None


def local_card_keys(pid):
    out = psql(f"SELECT jsonb_object_keys(card_db) FROM plugins WHERE id={pid};")
    return None if out is None else _lines(out)


def local_deck_keys(pid):
    out = psql(f"SELECT jsonb_object_keys(game_def->'preBuiltDecks') FROM plugins WHERE id={pid};")
    return _lines(out)


def local_gamedef_keys(pid):
    out = psql(f"SELECT jsonb_object_keys(game_def) FROM plugins WHERE id={pid};")
    return _lines(out)


# ---------- commands ----------
def keys_for(which):
    return list(PLUGINS) if which == "all" else [which]


def cmd_images(args):
    grand_missing = grand_dl = grand_fail = 0
    for key in keys_for(args.which):
        p = PLUGINS[key]
        mirror = p["mirror"]
        mirror.mkdir(parents=True, exist_ok=True)
        live = fetch_live(key, args.refresh)
        gd = live.get("game_def", live)
        prefix = english_prefix(gd, p["fallback_prefix"])
        urls = set()
        collect_image_urls(live.get("card_db", {}), urls)
        skip = set() if args.retry_unavailable else load_unavailable(mirror)

        missing = []  # (image_url, remote, local)
        for iu in sorted(urls):
            lp = local_path(iu, mirror)
            if lp.exists() and lp.stat().st_size > 0:
                continue
            name = iu.lstrip("/")
            if name in skip:
                continue
            missing.append((iu, remote_url(iu, prefix), lp))

        print(f"\n[{key}] live referenced images: {len(urls)} | missing locally: {len(missing)}"
              + (f" | skipping {len(skip)} known-unavailable" if skip else ""))
        grand_missing += len(missing)
        if not missing:
            continue
        if not args.apply:
            for iu, rem, lp in missing[:15]:
                print(f"    MISSING {iu}")
            if len(missing) > 15:
                print(f"    ... and {len(missing) - 15} more (run with --apply to download)")
            continue

        new_unavailable = set(skip)
        ok = fail = 0

        def grab(item):
            iu, rem, lp = item
            body, code = http_get(rem, timeout=45)
            if body and code == 200 and len(body) > 0:
                lp.parent.mkdir(parents=True, exist_ok=True)
                lp.write_bytes(body)
                return ("ok", iu, code)
            return ("fail", iu, code)

        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            for status, iu, code in ex.map(grab, missing):
                if status == "ok":
                    ok += 1
                else:
                    fail += 1
                    new_unavailable.add(iu.lstrip("/"))
        save_unavailable(mirror, new_unavailable)
        grand_dl += ok
        grand_fail += fail
        print(f"    downloaded {ok} | failed {fail} (recorded in {unavailable_file(mirror).name} so they're skipped next time)")
        if fail:
            print(f"    note: failures are typically fan/custom content not on the official CDN (also broken on live).")

    print(f"\nSUMMARY: missing={grand_missing} downloaded={grand_dl} unavailable={grand_fail}")
    if grand_dl:
        print("Downloaded images are in the gitignored mirror dir(s); no re-import needed for art that")
        print("belongs to cards already in the local card_db. For NEW cards, sync data first (see `report`).")


def cmd_report(args):
    for key in keys_for(args.which):
        p = PLUGINS[key]
        live = fetch_live(key, args.refresh)
        lgd = live.get("game_def", {})
        lcards = live.get("card_db", {})
        live_ver = live.get("version", lgd.get("version", "?"))
        print(f"\n========== {key.upper()}  (live id {p['live_id']} '{p['local_name']}') ==========")
        print(f"live: version {live_ver} | cards {len(lcards)} | decks {len(lgd.get('preBuiltDecks', {}))}")

        pid = local_plugin_id(p["local_name"])
        if pid is None:
            print("local: plugin NOT found in DB (is docker up? has it been imported?). Skipping content diff.")
        else:
            lk = local_card_keys(pid) or set()
            live_keys = set(lcards.keys())
            added = live_keys - lk
            removed = lk - live_keys
            ldecks = local_deck_keys(pid)
            live_decks = set(lgd.get("preBuiltDecks", {}).keys())
            gkdiff = set(lgd.keys()) ^ local_gamedef_keys(pid)
            print(f"local: id {pid} | cards {len(lk)} | decks {len(ldecks)}")
            print(f"  cards: +{len(added)} new upstream / -{len(removed)} only-local")
            for cid in list(sorted(added))[:10]:
                nm = _card_name(lcards.get(cid, {}))
                print(f"    NEW CARD {cid}  {nm}")
            if len(added) > 10:
                print(f"    ... and {len(added) - 10} more new cards")
            dadded = live_decks - ldecks
            print(f"  decks: +{len(dadded)} new upstream / -{len(ldecks - live_decks)} only-local")
            for d in list(sorted(dadded))[:10]:
                print(f"    NEW DECK {d}")
            if gkdiff:
                print(f"  game_def top-level key differences: {sorted(gkdiff)}")

        # image gap (audit only) -- split recoverable vs known-unavailable (skip-cached)
        urls = set()
        collect_image_urls(lcards, urls)
        skip = load_unavailable(p["mirror"])
        missing = [iu for iu in urls if not local_path(iu, p["mirror"]).exists()]
        recoverable = [iu for iu in missing if iu.lstrip("/") not in skip]
        known = len(missing) - len(recoverable)
        extra = f" | {known} known-unavailable (skip-cached)" if known else ""
        tail = f"  -> run: images {key} --apply" if recoverable else "  -> complete"
        print(f"  images: {len(urls)} referenced | {len(recoverable)} recoverable-missing{extra}{tail}")

    _git_report()


def _card_name(card):
    if isinstance(card, dict):
        sides = card.get("sides", card)
        a = sides.get("A") if isinstance(sides, dict) else None
        if isinstance(a, dict):
            return a.get("name", "")
    return ""


def _git_report():
    print("\n========== CODE (git remote 'upstream') ==========")
    try:
        subprocess.run(["git", "-C", str(REPO), "fetch", "upstream", "--quiet"],
                       capture_output=True, timeout=120)
        cnt = subprocess.run(["git", "-C", str(REPO), "rev-list", "--count", "HEAD..upstream/main"],
                             capture_output=True, text=True).stdout.strip()
        print(f"new upstream commits not in HEAD: {cnt or '0'}")
        if cnt and cnt != "0":
            log = subprocess.run(["git", "-C", str(REPO), "log", "--oneline", "-n", "15", "HEAD..upstream/main"],
                                 capture_output=True, text=True).stdout
            print(log.rstrip())
            print("Apply code with the documented merge process (see memory: fork-upstream-relationship). NOT auto-merged.")
    except Exception as e:
        print(f"(git upstream check skipped: {e})")


# ---------- integrate new playable content (cards / decks / menu) ----------
import re


def _strip_comments(txt):
    # mirror backend Merger.remove_comments: drop // line comments but keep http:// / https://
    return re.sub(r"(?<!:)//[^\n\r]*", "", txt)


def card_sides(card):
    """Return {sideLetter: face} for a live card, handling flat {A,B} and {sides:{A,B}}."""
    if not isinstance(card, dict):
        return {}
    if isinstance(card.get("sides"), dict):
        return card["sides"]
    return {k: v for k, v in card.items() if k in "ABCDEFGH" and isinstance(v, dict)}


def tsv_header(plugin_key):
    tdir = PLUGINS[plugin_key]["plugin_dir"] / "tsvs"
    files = sorted(tdir.glob("*.tsv"))
    files.sort(key=lambda f: (f.name != "marvelcdb.tsv"))  # prefer marvelcdb.tsv for MC
    if not files:
        raise SystemExit(f"no existing TSV to read a header from in {tdir}")
    with open(files[0]) as f:
        return f.readline().rstrip("\r\n").split("\t")


def _npk(face):
    try:
        return int(face.get("numberInPack") or 0)
    except Exception:
        return 0


def card_to_rows(cardid, card, header):
    """Live card -> TSV rows (A, plus B.. for multi_sided). Faithful to TsvProcess row ordering."""
    sides = card_sides(card)
    A = sides.get("A", {})

    def row(face, force_id=False):
        out = []
        for col in header:
            v = face.get(col)
            if col == "databaseId" and v in (None, "") and force_id:
                v = cardid
            out.append("" if v is None else str(v))
        return out

    rows = [row(A)]
    if A.get("cardBack") == "multi_sided":
        for letter in "BCDEFGH":
            if letter in sides:
                rows.append(row(sides[letter], force_id=True))
    return rows


def simulate_tsv(rows):
    """Mini TsvProcess for validation: rows incl header -> {id: {A,B,..}}."""
    header = rows[0]
    db, ms_id, ms_side = {}, "", "A"
    nxt = {"B": "C", "C": "D", "D": "E", "E": "F", "F": "G", "G": "H"}
    for r in rows[1:]:
        face = {header[j]: r[j] for j in range(len(header))}
        did = face["databaseId"]
        if did == ms_id:
            db[did][ms_side] = face
            ms_side = nxt.get(ms_side, "X")
        else:
            db[did] = {"A": face, "B": {**{h: None for h in header}, "name": face["cardBack"]}}
            ms_id, ms_side = (did, "B") if face["cardBack"] == "multi_sided" else ("", "A")
    return db


def gen_tsvs(plugin_key, new_ids, cdb, header, apply):
    """Group new cards by setUuid (per-set file, matching ALeP convention) else one synced file."""
    tdir = PLUGINS[plugin_key]["plugin_dir"] / "tsvs"
    groups = {}
    for cid in new_ids:
        setu = card_sides(cdb[cid]).get("A", {}).get("setUuid")
        fname = f"{setu}.tsv" if setu else f"zz-synced-{plugin_key}.tsv"
        groups.setdefault(fname, []).append(cid)
    plan = []
    for fname, ids in sorted(groups.items()):
        ids.sort(key=lambda c: _npk(card_sides(cdb[c]).get("A", {})))
        path = tdir / fname
        rows = []
        for cid in ids:
            rows += card_to_rows(cid, cdb[cid], header)
        plan.append((path, len(ids), rows))
        if apply:
            if path.exists():
                with open(path, "a") as f:
                    f.writelines("\t".join(r) + "\n" for r in rows)
            else:
                with open(path, "w") as f:
                    f.write("\t".join(header) + "\n")
                    f.writelines("\t".join(r) + "\n" for r in rows)
    return plan


def gen_decks(plugin_key, new_deck_keys, live_pbd, apply):
    path = PLUGINS[plugin_key]["plugin_dir"] / "jsons" / f"zz-synced-{plugin_key}-decks.json"
    existing = json.loads(path.read_text()).get("preBuiltDecks", {}) if path.exists() else {}
    added = {k: live_pbd[k] for k in new_deck_keys if k in live_pbd}
    if apply and added:
        path.write_text(json.dumps({"preBuiltDecks": {**existing, **added}}, indent=2, ensure_ascii=False) + "\n")
    return path, added


def _menu_files(plugin_key):
    out = []
    for f in sorted((PLUGINS[plugin_key]["plugin_dir"] / "jsons").glob("*.json")):
        try:
            j = json.loads(_strip_comments(f.read_text()))
        except Exception:
            continue
        if isinstance(j, dict) and "deckMenu" in j:
            out.append((f, j, "//" in f.read_text()))
    return out


def _clone_live_subtree(live_dm, path_labels):
    cur = live_dm
    for lab in path_labels:
        cur = next((s for s in cur.get("subMenus", []) or [] if s.get("label") == lab), None)
        if cur is None:
            return None
    return json.loads(json.dumps(cur))  # deep copy


def integrate_menu(plugin_key, new_set, live, apply):
    """Surface new decks in the menu. New top-level cycles -> auto-written synced menu file.
    Additions into an EXISTING cycle -> returned as manual-insert instructions (preserve formatting)."""
    live_dm = live["game_def"].get("deckMenu", {})
    # holding nodes = nodes whose deckLists reference a new deck id; key by full label-path
    holders = {}
    def walk(node, path):
        if not isinstance(node, dict):
            return
        here = path + ([node["label"]] if node.get("label") is not None else [])
        if any(dl.get("deckListId") in new_set for dl in node.get("deckLists", []) or []):
            holders[tuple(here)] = node
        for s in node.get("subMenus", []) or []:
            walk(s, here)
    for s in live_dm.get("subMenus", []) or []:
        walk(s, [])

    local_top = {}
    for f, j, has_c in _menu_files(plugin_key):
        for s in j["deckMenu"].get("subMenus", []) or []:
            local_top.setdefault(s.get("label"), f)

    synced_path = PLUGINS[plugin_key]["plugin_dir"] / "jsons" / f"zz-synced-{plugin_key}.menu.json"
    synced = json.loads(synced_path.read_text()) if synced_path.exists() else {"deckMenu": {"subMenus": []}}
    auto, manual = [], []
    for path_labels, node in sorted(holders.items()):
        new_dls = [dl for dl in node.get("deckLists", []) or [] if dl.get("deckListId") in new_set]
        L1 = path_labels[0]
        if L1 not in local_top:
            # brand-new top-level cycle: safe to add as a separate file (lists concat on merge)
            sub = _clone_live_subtree(live_dm, list(path_labels[:1]))
            if sub is not None:
                synced["deckMenu"]["subMenus"].append(sub)
                auto.append((str(synced_path), " > ".join(path_labels)))
        else:
            manual.append({
                "owning_file": str(local_top[L1]),
                "path": " > ".join(path_labels),
                "insert_node": node if (len(path_labels) >= 2) else {"deckLists": new_dls},
                "new_deckLists": new_dls,
            })
    if apply and auto:
        synced_path.write_text(json.dumps(synced, indent=4, ensure_ascii=False) + "\n")
    return auto, manual


def cmd_integrate(args):
    for key in keys_for(args.which):
        p = PLUGINS[key]
        print(f"\n========== INTEGRATE {key.upper()} ('{p['local_name']}') ==========")
        pid = local_plugin_id(p["local_name"])
        if pid is None:
            print("  local plugin not in DB (is docker up + imported?). Skipping."); continue
        live = fetch_live(key, args.refresh)
        lcards = live.get("card_db", {})
        live_pbd = live["game_def"].get("preBuiltDecks", {})
        local_cards = local_card_keys(pid) or set()
        local_decks = local_deck_keys(pid)
        new_ids = [k for k in lcards if k not in local_cards]
        new_decks = [k for k in live_pbd if k not in local_decks]
        print(f"  new cards: {len(new_ids)} | new decks: {len(new_decks)}")
        if not new_ids and not new_decks:
            print("  nothing to integrate."); continue

        header = tsv_header(key)
        tsv_plan = gen_tsvs(key, new_ids, lcards, header, args.apply) if new_ids else []
        deck_path, added = gen_decks(key, new_decks, live_pbd, args.apply)
        auto_menu, manual_menu = integrate_menu(key, set(new_decks), live, args.apply)

        # validate
        for path, ncards, rows in tsv_plan:
            sim = simulate_tsv([header] + rows)
            print(f"  {'WROTE' if args.apply else 'PLAN'} TSV {path.name}: {ncards} cards, {len(rows)} rows (sim -> {len(sim)} entries)")
        if added:
            known = local_cards | set(new_ids)
            unresolved = sorted({c["databaseId"] for d in added.values() for c in d.get("cards", []) if c["databaseId"] not in known})
            print(f"  {'WROTE' if args.apply else 'PLAN'} decks -> {deck_path.name}: {len(added)} decks; unresolved card refs: {len(unresolved)}")
            if unresolved:
                print("    WARNING unresolved:", unresolved[:5])
        for fpath, path in auto_menu:
            print(f"  {'WROTE' if args.apply else 'PLAN'} menu (new cycle) -> {Path(fpath).name}: {path}")
        for m in manual_menu:
            print(f"  MENU EDIT NEEDED in {Path(m['owning_file']).name}: insert under existing cycle path '{m['path']}'")
            print("    node to add (or merge its deckLists into the matching node):")
            print("    " + json.dumps(m["insert_node"], ensure_ascii=False))

        if args.apply:
            print("  -> next: images --apply, then re-import + restart backend.")
        else:
            print("  (dry-run; re-run with --apply to write card/deck/new-cycle files)")


def main():
    ap = argparse.ArgumentParser(description="Sync DragnCards plugin resources from live upstream.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("report", "images", "integrate"):
        s = sub.add_parser(name)
        s.add_argument("which", nargs="?", default="all", choices=["mc", "lotr", "all"])
        s.add_argument("--refresh", action="store_true")
        s.add_argument("--retry-unavailable", action="store_true")
        s.add_argument("--workers", type=int, default=8)
        if name in ("images", "integrate"):
            help_txt = "actually download missing images" if name == "images" else "actually write card/deck/new-cycle files"
            s.add_argument("--apply", action="store_true", help=help_txt)
    args = ap.parse_args()
    {"images": cmd_images, "integrate": cmd_integrate}.get(args.cmd, cmd_report)(args)


if __name__ == "__main__":
    main()
