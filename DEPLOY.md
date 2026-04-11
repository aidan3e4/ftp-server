# Deployment

## Prerequisites

```bash
curl -L https://fly.io/install.sh | sh
fly auth login
```

## First-time setup

```bash
cp .env.example .env
# Fill in .env with your credentials

fly apps create ftp-server-yourname   # update app name in fly.toml
./deploy_first.sh                     # sets secrets and deploys
```

Then set the masquerade address (required for passive FTP):

```bash
fly ips list
fly secrets set MASQUERADE_ADDRESS=<ip>
./deploy.sh
```

## Redeploying

```bash
./deploy.sh
```

## Camera configuration

| Field    | Value                          |
|----------|--------------------------------|
| Host     | `ftp-server-yourname.fly.dev`  |
| Port     | `2121`                         |
| User     | value of `FTP_USER` in `.env`  |
| Password | value of `FTP_PASSWORD` in `.env` |

## Useful commands

```bash
fly logs          # view logs
fly status        # check app status
fly ssh console   # shell into container
fly secrets list  # verify secrets
```

## Notes

- Passive FTP (ports 60000–60010) may be unreliable on Fly.io's shared Anycast IPs.
  Allocate a dedicated IPv4 for $2/month if needed: `fly ips allocate-v4`
- Secrets only need to be set once (`deploy_first.sh`). Use `deploy.sh` for all subsequent deploys.
