#!/usr/bin/env python3
"""
FTP Server for Reolink Camera Uploads

A simple FTP server that accepts uploads from Reolink cameras.
Uploads files directly to S3.
Designed to run on cloud servers (e.g., runpod) and be accessible from the internet.
"""

import os
import sys
from pathlib import Path
from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler
from pyftpdlib.servers import FTPServer
from dotenv import load_dotenv
import logging
import boto3
from botocore.exceptions import ClientError


# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

load_dotenv()

# Configuration from environment variables
FTP_PORT = int(os.environ.get("FTP_PORT", "2121"))
FTP_HOST = os.environ.get("FTP_HOST", "0.0.0.0")  # 0.0.0.0 to accept connections from anywhere
FTP_MAX_CONS = int(os.environ.get("FTP_MAX_CONS", "256"))
FTP_MAX_CONS_PER_IP = int(os.environ.get("FTP_MAX_CONS_PER_IP", "5"))
PASSIVE_PORT_START = int(os.environ.get("PASSIVE_PORT_START", "60000"))
PASSIVE_PORT_END = int(os.environ.get("PASSIVE_PORT_END", "60100"))

# S3 Configuration
S3_REGION = os.environ.get("S3_REGION", "us-east-1")
S3_PREFIX = os.environ.get("S3_PREFIX", "ftp_uploads/")
AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "")

# FTP_USER is both the FTP username and the S3 bucket name
FTP_USER = os.environ.get("FTP_USER", "")
FTP_PASSWORD = os.environ.get("FTP_PASSWORD", "")


def get_camera_configs() -> list[dict]:
    if not FTP_USER:
        logger.warning("FTP_USER not set — no cameras registered")
        return []
    return [{"username": u.strip().lower(), "bucket": f"vibecast-{u.strip().lower()}"} for u in FTP_USER.split(",") if u.strip()]

# Local temporary directory for receiving files before S3 upload
FTP_UPLOAD_DIR = Path("/tmp/ftp_uploads")

# Permissions
# "elradfmwMT" means:
# e = change directory (CWD, CDUP commands)
# l = list files (LIST, NLST, STAT, MLSD, MLST, SIZE commands)
# r = retrieve file from the server (RETR command)
# a = append data to an existing file (APPE command)
# d = delete file or directory (DELE, RMD commands)
# f = rename file or directory (RNFR, RNTO commands)
# m = create directory (MKD command)
# w = store a file to the server (STOR, STOU commands)
# M = change file mode/permission (SITE CHMOD command)
# T = change file modification time (SITE MTIME command)
FTP_PERMISSIONS = os.environ.get("FTP_PERMISSIONS", "elradfmwMT")


def upload_to_s3(local_file_path: Path, s3_key: str, bucket: str) -> bool:
    """Upload a file to S3 and delete the local copy."""
    if not bucket:
        logger.warning("S3 bucket not configured for this user. File will remain local.")
        return False

    try:
        s3_client = boto3.client(
            's3',
            region_name=S3_REGION,
            aws_access_key_id=AWS_ACCESS_KEY_ID if AWS_ACCESS_KEY_ID else None,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY if AWS_SECRET_ACCESS_KEY else None
        )

        s3_client.upload_file(str(local_file_path), bucket, s3_key)
        logger.info(f"Uploaded to S3: s3://{bucket}/{s3_key}")

        local_file_path.unlink()
        logger.info(f"Deleted local file: {local_file_path}")

        return True

    except ClientError as e:
        logger.error(f"Failed to upload {local_file_path} to S3: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error uploading to S3: {e}")
        return False


class CustomFTPHandler(FTPHandler):
    """Custom FTP handler with additional logging."""

    # Populated by setup_ftp_server: maps username -> S3 bucket
    bucket_map: dict[str, str] = {}

    def on_connect(self):
        logger.info(f"Client connected: {self.remote_ip}:{self.remote_port}")

    def on_disconnect(self):
        logger.info(f"Client disconnected: {self.remote_ip}:{self.remote_port}")

    def on_login(self, username):
        logger.info(f"User '{username}' logged in from {self.remote_ip}")

    def on_logout(self, username):
        logger.info(f"User '{username}' logged out")

    def on_file_sent(self, file):
        logger.info(f"File sent: {file}")

    def on_file_received(self, file):
        logger.info(f"File received: {file}")

        local_path = Path(file)
        # Each user's home dir is FTP_UPLOAD_DIR/<username>, so strip that prefix
        user_upload_dir = FTP_UPLOAD_DIR / self.username
        relative_path = local_path.relative_to(user_upload_dir)
        s3_key = f"{S3_PREFIX}{relative_path}"

        bucket = self.bucket_map.get(self.username, "")
        upload_to_s3(local_path, s3_key, bucket)

    def on_incomplete_file_sent(self, file):
        logger.warning(f"Incomplete file sent: {file}")

    def on_incomplete_file_received(self, file):
        logger.warning(f"Incomplete file received: {file}")


def setup_ftp_server():
    """Setup and configure the FTP server."""

    FTP_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    authorizer = DummyAuthorizer()
    cameras = get_camera_configs()
    bucket_map = {}

    for camera in cameras:
        username = camera["username"]
        user_dir = FTP_UPLOAD_DIR / username
        user_dir.mkdir(parents=True, exist_ok=True)
        authorizer.add_user(username, FTP_PASSWORD, str(user_dir), perm=FTP_PERMISSIONS)
        bucket_map[username] = camera["bucket"]
        logger.info(f"Registered camera user '{username}' -> bucket '{camera['bucket']}'")

    handler = CustomFTPHandler
    handler.authorizer = authorizer
    handler.bucket_map = bucket_map

    # Define a customized banner
    handler.banner = "Vibecast FTP Server ready."

    # Set passive ports range
    handler.passive_ports = range(PASSIVE_PORT_START, PASSIVE_PORT_END)

    # For Docker/NAT, set masquerade address if provided
    masquerade_address = os.environ.get("MASQUERADE_ADDRESS", "")
    if masquerade_address:
        handler.masquerade_address = masquerade_address
        logger.info(f"Masquerade address set to: {masquerade_address}")

    # Instantiate FTP server class and listen on FTP_HOST:FTP_PORT
    address = (FTP_HOST, FTP_PORT)
    server = FTPServer(address, handler)

    # Set connection limits
    server.max_cons = FTP_MAX_CONS
    server.max_cons_per_ip = FTP_MAX_CONS_PER_IP

    return server


def main():
    """Main function to start the FTP server."""
    logger.info("=" * 70)
    logger.info("Starting Vibecast FTP Server")
    logger.info("=" * 70)
    logger.info(f"Host: {FTP_HOST}")
    logger.info(f"Port: {FTP_PORT}")
    logger.info(f"Temporary upload directory: {FTP_UPLOAD_DIR.absolute()}")
    logger.info(f"Max connections: {FTP_MAX_CONS}")
    logger.info(f"Max connections per IP: {FTP_MAX_CONS_PER_IP}")
    logger.info(f"S3 Region: {S3_REGION}")
    logger.info(f"S3 Prefix: {S3_PREFIX}")
    logger.info("")
    cameras = get_camera_configs()
    for camera in cameras:
        bucket = camera["bucket"]
        status = f"s3://{bucket}" if bucket else "NO BUCKET (files stay local)"
        logger.info(f"  Camera user '{camera['username']}' -> {status}")
    logger.info("=" * 70)

    # Setup server
    server = setup_ftp_server()

    # Start serving
    try:
        logger.info("FTP server started. Press Ctrl+C to stop.")
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("\nShutting down FTP server...")
        server.close_all()
        logger.info("FTP server stopped.")
        return 0
    except Exception as e:
        logger.error(f"Error running FTP server: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
