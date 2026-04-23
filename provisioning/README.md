# Provisioning

Tiny FastAPI service for issuing one Cloudflare Tunnel per paired Mac.

This runs on a VPS behind its own public hostname, for example `https://remotecc.soli.blue`. It is not in the chat/files/git data path. It only handles pairing, tunnel creation, heartbeat, and revocation.

## Run locally

```sh
cd provisioning
python3.13 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Use Python 3.12 or 3.13. Fill in `.env` on the VPS. Do not commit real Cloudflare tokens.

The built-in rate limiter is process-local and IP-based. It is enough for one VPS process. If this runs with multiple workers later, move rate limits to Cloudflare rules or Redis.

Production command:

```sh
gunicorn app.main:app --worker-class uvicorn.workers.UvicornWorker --bind 127.0.0.1:8080
```

## Deploy

Deploy to Medina:

```sh
.claude/agents/deployer/deploy-provisioning.sh
```

`provisioning/deploy-medina.sh` is a convenience wrapper around that deployer-owned script.

The script syncs this folder to `/opt/remotecc/provisioning`, writes root-only env files under `/etc/remotecc`, installs Python dependencies into a remote venv, creates or updates the `remotecc-provisioning-medina` Cloudflare Tunnel, maps `remotecc.soli.blue` to the service, starts systemd units, and verifies health.

## Endpoints

```text
GET  /health
POST /pairing-sessions
POST /pairing-sessions/{pairingId}/completion
PUT  /macs/{macId}
PUT  /macs/{macId}/tunnel
DELETE /macs/{macId}/tunnel
PUT  /macs/{macId}/heartbeat
```

## Structure

```text
app/
  main.py
  api/        HTTP routes
  core/       config and security
  db/         raw SQLite connection, schema, queries
  models/     Pydantic row/domain models
  schemas/    Pydantic request and response models
  services/   Cloudflare API client
```

## Hostnames

With the default env, Mac tunnel hostnames look like:

```text
abc123-remotecc.soli.blue
```

The provisioning service itself can live at:

```text
remotecc.soli.blue
```
