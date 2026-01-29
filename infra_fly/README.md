# Fly.io Deployment

Deploy the FTP server to Fly.io's free tier.

## Important Limitations

Fly.io has some challenges for FTP:
- **No dedicated IP on free tier** - Uses shared Anycast IPs
- **Port ranges are tedious** - Each port needs explicit config
- **Passive FTP may be unreliable** - Due to Anycast networking

This config uses a reduced passive port range (60000-60010) to keep config manageable.

## Prerequisites

1. Install the Fly CLI:
```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"
```

2. Create account (no credit card required for free tier):
```bash
fly auth signup
```

## Step 1: Create the App

```bash
cd infra_fly

# Create the app (choose a unique name)
fly apps create ftp-server-yourname
```

Update `fly.toml` with your app name.

## Step 2: Set Secrets

```bash
# FTP credentials
fly secrets set FTP_USER=reolink
fly secrets set FTP_PASSWORD=your-secure-password

# AWS S3 credentials
fly secrets set S3_BUCKET=your-bucket-name
fly secrets set S3_REGION=eu-central-1
fly secrets set S3_PREFIX=ftp_uploads/
fly secrets set AWS_ACCESS_KEY_ID=AKIA...
fly secrets set AWS_SECRET_ACCESS_KEY=your-secret-key
```

## Step 3: Deploy

```bash
fly deploy
```

## Step 4: Get Your IP and Set Masquerade Address

```bash
# Get the app's IP address
fly ips list
```

Then set it as the masquerade address:
```bash
fly secrets set MASQUERADE_ADDRESS=<your-fly-ip>
```

Redeploy to pick up the change:
```bash
fly deploy
```

## Step 5: Configure Your Camera

- **FTP Server**: `ftp-server-yourname.fly.dev` or the IP from `fly ips list`
- **Port**: `2121`
- **Username**: `reolink`
- **Password**: Your configured password

## Useful Commands

```bash
# View logs
fly logs

# SSH into the container
fly ssh console

# Check status
fly status

# Scale down (stop) to save resources
fly scale count 0

# Scale up (start)
fly scale count 1
```

## Allocate Dedicated IP (Optional, $2/month)

For more reliable FTP, allocate a dedicated IPv4:

```bash
fly ips allocate-v4
```

This gives you a stable IP instead of shared Anycast.

## Troubleshooting

### FTP connection times out
- Passive mode may not work reliably with Fly.io's Anycast
- Try allocating a dedicated IP ($2/month)
- Ensure MASQUERADE_ADDRESS is set correctly

### App won't start
- Check logs: `fly logs`
- Verify secrets are set: `fly secrets list`

### Camera can't connect
- Use IP address instead of hostname
- Verify firewall/ports with: `fly ips list`

## Free Tier Limits

- 3 shared VMs (256MB each)
- Shared IPv4 (Anycast)
- 160GB outbound data/month

## Cost if Needed

- Dedicated IPv4: $2/month
- Additional memory: $0.15/GB/month
