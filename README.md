# FTP Server for Camera Uploads

An FTP server that accepts uploads from cameras and stores them in S3. Designed to run on Fly.io and be accessible from the internet.

See [DEPLOY.md](DEPLOY.md) for deployment instructions.

## Multi-camera setup

Each camera gets its own FTP username and S3 bucket. Configure all cameras in a single `CAMERA_USERS` secret:

```
CAMERA_USERS=camera_front:secretpass1:my-bucket-front,camera_back:secretpass2:my-bucket-back
```

Format: `username:password:s3-bucket`, comma-separated, one entry per camera.

To add or update cameras, update the secret and redeploy:

```bash
fly secrets set CAMERA_USERS="camera_front:pass1:bucket-front,camera_back:pass2:bucket-back,camera_side:pass3:bucket-side"
fly deploy
```

Each camera user uploads into an isolated directory and its files are routed to its own S3 bucket under the `S3_PREFIX` path.

## Single-camera (legacy)

If `CAMERA_USERS` is not set, the server falls back to the legacy `FTP_USER` / `FTP_PASSWORD` / `S3_BUCKET` env vars.

## Camera FTP settings

| Field    | Value                                        |
|----------|----------------------------------------------|
| Host     | `ftp-server-yourname.fly.dev`                |
| Port     | `2121`                                       |
| User     | the username you set in `CAMERA_USERS`       |
| Password | the password you set in `CAMERA_USERS`       |
| Mode     | Passive                                      |
