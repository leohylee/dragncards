# Deploying DragnCards to AWS (single-user, on/off to save money)

Run DragnCards at **https://dragncards.leohyl.app** on one EC2 instance that you
**stop when idle**. Because the EBS volume persists across stop/start, the
compiled Elixir `_build`, the Postgres data, and the card-image mirrors all
survive a shutdown — so turning it back on is a ~2-3 min container start, not a
10-30 min recompile.

```
phone/browser ──HTTPS──> dragncards.leohyl.app  (Route53 A → instance public IP, set on boot)
                              │
                        ┌─────▼──── EC2 t3.medium (Amazon Linux 2023) ─────────────────┐
                        │  Caddy :443  /be/*  /socket/*  ──> backend :4000 (loopback)   │
                        │              everything else    ──> /srv/dragncards/frontend/build │
                        │  docker compose -f compose.prod.yml: backend + postgres        │
                        │  EBS gp3 30GB: pgdata, deps, _build, mc-cards, lotrlcg-cards   │
                        └────────────────────────────────────────────────────────────────┘
   phone button ──HTTPS──> Lambda Function URL (?token=…&action=start|stop) ──> ec2:Start/StopInstances
```

Only ports **443/80** (Caddy) and **22** (SSH, your IP only) are public. Backend
4000 and Postgres are loopback-only and reached by Caddy over localhost.

Rough cost: **~$3/mo idle** (EBS) **+ ~$0.04/hr while running** ≈ **$4-6/mo** for
light use. No Elastic IP, no ALB, no CloudFront on purpose — those would bill
even while "off".

---

## Files in this repo used below
- `compose.prod.yml` — prod stack (postgres + backend only; backend bound to 127.0.0.1; no Node dev server).
- `deploy/Caddyfile` — TLS + reverse proxy (`/be/*`, `/socket/*` → :4000; static SPA otherwise).
- `deploy/update-route53.sh` — boot-time DNS update to the instance's current public IP.
- `deploy/dragncards.service` — systemd: run the DNS update, then `docker compose up`.
- `deploy/instance-route53-policy.json` — IAM policy for the **instance** role.
- `deploy/lambda/handler.py` + `iam-policy.json` — the phone on/off button.

---

## 1. Provision the instance
- Launch **t3.medium** (2 vCPU / 4 GB — needed for the first Elixir compile),
  **x86_64**, **Amazon Linux 2023**, root volume **gp3 30 GB**.
- Security group inbound: `443` and `80` from `0.0.0.0/0`; `22` from **your IP only**.
  Do **not** open 4000 or 5432/5433.
- Create an **IAM role for the instance** with `deploy/instance-route53-policy.json`
  (fill in the `leohyl.app` `ZONE_ID`) and attach it to the instance.
- Install Docker + compose plugin + Caddy + AWS CLI v2, e.g. on AL2023:
  ```bash
  sudo dnf install -y docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker ec2-user
  # docker compose plugin
  sudo mkdir -p /usr/libexec/docker/cli-plugins
  sudo curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
       -o /usr/libexec/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
  # Caddy runs as a container in the compose stack (see compose.prod.yml) — no host install.
  # AWS CLI v2 is preinstalled on AL2023; otherwise install it.
  ```

## 2. Get the code + the big offline assets onto the box
```bash
sudo mkdir -p /srv && sudo chown ec2-user:ec2-user /srv
git clone <your-fork-url> /srv/dragncards
```
The card-image mirrors and other build artifacts are **gitignored**, so copy them
from your Mac (these are ~1.4 GB + ~0.9 GB). From the Mac:
```bash
rsync -avz --progress \
  frontend/public/mc-cards frontend/public/lotrlcg-cards \
  ec2-user@<instance>:/srv/dragncards/frontend/public/
```
(You do **not** need to ship `dragncards-backup_*.zip`, `node_modules`, or `backend/deps` —
deps are fetched on first boot.)

## 3. Build the frontend as a static bundle
The React app reads its backend locations at **build time**:
- `backendUrl` = `/be` when `REACT_APP_BE_HOSTNAME` is **unset** (relative → same origin).
- `wsRoot` = `REACT_APP_WS_URL`.

So build with **only** the WS URL set, leaving `REACT_APP_BE_HOSTNAME` unset:
```bash
cd /srv/dragncards/frontend
docker run --rm -v "$PWD":/app -w /app -e NODE_OPTIONS=--openssl-legacy-provider \
  -e REACT_APP_WS_URL=wss://dragncards.leohyl.app/socket \
  node:20-alpine sh -c "npm install --legacy-peer-deps && npm run build:css && npm run build"
```
This produces `frontend/build/`, which Caddy serves. (Re-run this whenever you
change frontend code.)

## 4. Install the systemd boot hook
Caddy is part of the compose stack (`compose.prod.yml`), so there's nothing to
install on the host — the systemd unit just updates DNS and brings the stack up:
```bash
sudo cp /srv/dragncards/deploy/dragncards.service /etc/systemd/system/
chmod +x /srv/dragncards/deploy/update-route53.sh
sudo systemctl daemon-reload
sudo systemctl enable --now dragncards.service   # DNS update + docker compose up (incl. Caddy)
```
Caddy needs the A record pointing at the box and port 80 reachable to issue the
Let's Encrypt cert — `dragncards.service` sets the A record before bringing up
the stack, so order is fine on a normal boot. On the very first setup you can run
the DNS script by hand: `/srv/dragncards/deploy/update-route53.sh`.

## 5. Seed the database (first boot only)
Once the backend container is up and has finished compiling:
```bash
cd /srv/dragncards
docker compose -f compose.prod.yml exec backend mix run priv/import_mc_plugin.exs
docker compose -f compose.prod.yml exec backend mix run priv/import_lotrlcg_plugin.exs
docker compose -f compose.prod.yml restart backend   # bust the ETS plugin cache
```

## 6. The phone on/off button (Lambda)
- Create a Lambda (Python 3.12) from `deploy/lambda/handler.py`
  (handler = `handler.handler`), env vars `INSTANCE_ID`, `SECRET_TOKEN` (a long
  random string), optional `SITE_URL`.
- Attach an execution role using `deploy/lambda/iam-policy.json` (fill in REGION,
  ACCOUNT_ID, INSTANCE_ID).
- Add a **Function URL** (auth type **NONE** — the `token` query param is the guard).
- On your phone, bookmark `https://<function-url>/?token=SECRET_TOKEN`. It shows a
  page with **Start / Stop / Open site**. Tap **Start**, wait ~2-3 min, tap **Open site**.

## 7. (Optional) auto-stop so you never forget
Add a CloudWatch alarm on low `NetworkOut`/`CPUUtilization` for N minutes → SNS →
a tiny "stop" Lambda; or a cron on the box that self-stops after an idle window.

---

## Turning it on/off
- **On:** phone button → Start (or `aws ec2 start-instances --instance-ids <id>`).
  On boot the box updates DNS and `docker compose up`s; Caddy serves once backend is ready.
- **Off:** phone button → Stop (or `aws ec2 stop-instances --instance-ids <id>`).
  EBS keeps everything, so the next start is fast.

## Verify (end-to-end)
1. `docker compose -f compose.prod.yml ps` → postgres + backend up; logs show Phoenix on 4000.
2. Plugin imports ran; opening a MC and a LOTR game shows card images (served from the on-box mirrors).
3. `curl -I https://dragncards.leohyl.app` → 200 with a valid cert.
4. In a browser: log in, take a realtime action (proves `wss://…/socket` through Caddy).
5. Stop via the button → site down, AWS shows `stopped`. Start → DNS updates, site back in ~2-3 min, **no** full recompile.
6. Check the Billing console after a few sessions.

## Notes / gotchas
- **Public registration:** the app is internet-reachable. Since only you should use
  it, consider disabling signups (or tightening `check_origin` in
  `backend/config/dev.exs` to the domain) once it's working.
- **Backend runs in dev mode** (`mix phx.server`), mirroring your local setup —
  fine for one user. A `MIX_ENV=prod` release is a later optimization.
- **No Elastic IP on purpose.** If you ever prefer a stable IP, allocate one and
  drop step 5's DNS script — but note a stopped instance's EIP still bills.
