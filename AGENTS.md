# AGENTS.md

Context for AI agents working in this repo.

## What this is

A minimal FTP server that receives image uploads from cameras and forwards them to S3. Runs on Fly.io. The entire server logic lives in `server.py`.

## Key design decisions

- **One FTP user per camera.** Each user maps to a dedicated S3 bucket, configured via the `CAMERA_USERS` env var. No runtime API — changes require updating the secret and redeploying.
- **Files are transient.** Files land in `/tmp/ftp_uploads/<username>/`, get uploaded to S3 via `upload_to_s3()`, then are deleted immediately. No persistent local storage.
- **Single process.** `pyftpdlib` handles all connections in one event loop. No workers, no queue.

## Environment variables

| Variable        | Required | Description |
|-----------------|----------|-------------|
| `CAMERA_USERS`  | Yes (preferred) | `user:pass:bucket,...` — one entry per camera |
| `FTP_USER` / `FTP_PASSWORD` / `S3_BUCKET` | Legacy fallback | Used when `CAMERA_USERS` is not set |
| `S3_REGION`     | No       | Default: `us-east-1` |
| `S3_PREFIX`     | No       | S3 key prefix, default: `ftp_uploads/` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | No | Omit when using IAM roles |
| `MASQUERADE_ADDRESS` | Yes on Fly.io | Public IP for passive FTP |
| `PASSIVE_PORT_START` / `PASSIVE_PORT_END` | No | Default: 60000–60100 |

## Adding a camera

```bash
fly secrets set CAMERA_USERS="cam1:pass1:bucket1,cam2:pass2:bucket2"
fly deploy
```

## File layout

```
server.py        — all server logic
fly.toml         — Fly.io app config (ports, regions)
deploy.sh        — redeploy script
deploy_first.sh  — first-time deploy (sets all secrets from .env)
infra/           — Terraform for S3 buckets and IAM
infra_fly/       — Fly.io infrastructure notes
```

## Running locally

```bash
cp .env.example .env
# fill in CAMERA_USERS and AWS credentials
uv run python server.py
```

## Deployment

See [DEPLOY.md](DEPLOY.md).
