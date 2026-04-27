# Camera Setup Guide

## 1. Add the camera to the server

Set two secrets on Fly.io and redeploy:

```bash
fly secrets set FTP_USER=my-camera-bucket FTP_PASSWORD=yourpassword
fly deploy
```

`FTP_USER` is both the FTP username and the S3 bucket name — they must match. The bucket must already exist in S3.

Verify it registered correctly:

```bash
fly logs
# look for: Registered camera user 'my-camera-bucket' -> bucket 'my-camera-bucket'
```

## 2. Configure the camera (Reolink example)

On the camera's admin page go to **Settings → Surveillance → FTP**:

| Field         | Value                            |
|---------------|----------------------------------|
| Server        | `ftp-server-vibecast.fly.dev`    |
| Port          | `2121`                           |
| Username      | value of `FTP_USER`              |
| Password      | value of `FTP_PASSWORD`          |
| Transfer Mode | Passive                          |
| Directory     | `/`                              |

## 3. Verify uploads reach S3

Trigger a test upload from the camera, then check the bucket:

```bash
aws s3 ls s3://my-camera-bucket/ftp_uploads/ --recursive
```

## Troubleshooting

**Connection refused** — check the app is running: `fly status`

**Login failed** — username and password must match exactly what's in the secrets. Check with `fly secrets list`.

**Files not in S3** — check `fly logs` for upload errors. Most likely cause: the bucket doesn't exist or the IAM role lacks write permission.

**Passive mode errors** — make sure the camera is in passive mode. If still unreliable, allocate a dedicated IPv4: `fly ips allocate-v4`
