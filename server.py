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
FTP_USER = os.environ.get("FTP_USER", "reolink")
FTP_PASSWORD = os.environ.get("FTP_PASSWORD", "camera123")
FTP_PORT = int(os.environ.get("FTP_PORT", "2121"))
FTP_HOST = os.environ.get("FTP_HOST", "0.0.0.0")  # 0.0.0.0 to accept connections from anywhere
FTP_MAX_CONS = int(os.environ.get("FTP_MAX_CONS", "256"))
FTP_MAX_CONS_PER_IP = int(os.environ.get("FTP_MAX_CONS_PER_IP", "5"))
PASSIVE_PORT_START = int(os.environ.get("PASSIVE_PORT_START", "60000"))
PASSIVE_PORT_END = int(os.environ.get("PASSIVE_PORT_END", "60100"))

# S3 Configuration
S3_BUCKET = os.environ.get("S3_BUCKET", "")
S3_REGION = os.environ.get("S3_REGION", "us-east-1")
S3_PREFIX = os.environ.get("S3_PREFIX", "ftp_uploads/")  # Prefix for uploaded files
AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "")

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


def upload_to_s3(local_file_path: Path, s3_key: str) -> bool:
    """
    Upload a file to S3 and delete the local copy.

    Args:
        local_file_path: Path to the local file
        s3_key: S3 key (path) for the uploaded file

    Returns:
        True if upload succeeded, False otherwise
    """
    if not S3_BUCKET:
        logger.warning("S3_BUCKET not configured. File will remain local.")
        return False

    try:
        # Initialize S3 client
        s3_client = boto3.client(
            's3',
            region_name=S3_REGION,
            aws_access_key_id=AWS_ACCESS_KEY_ID if AWS_ACCESS_KEY_ID else None,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY if AWS_SECRET_ACCESS_KEY else None
        )

        # Upload file
        s3_client.upload_file(
            str(local_file_path),
            S3_BUCKET,
            s3_key
        )

        logger.info(f"Uploaded to S3: s3://{S3_BUCKET}/{s3_key}")

        # Delete local file after successful upload
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

    def on_connect(self):
        """Called when client connects."""
        logger.info(f"Client connected: {self.remote_ip}:{self.remote_port}")

    def on_disconnect(self):
        """Called when client disconnects."""
        logger.info(f"Client disconnected: {self.remote_ip}:{self.remote_port}")

    def on_login(self, username):
        """Called when client logs in."""
        logger.info(f"User '{username}' logged in from {self.remote_ip}")

    def on_logout(self, username):
        """Called when client logs out."""
        logger.info(f"User '{username}' logged out")

    def on_file_sent(self, file):
        """Called when file is successfully sent."""
        logger.info(f"File sent: {file}")

    def on_file_received(self, file):
        """Called when file is successfully received."""
        logger.info(f"File received: {file}")

        # Upload to S3
        local_path = Path(file)
        relative_path = local_path.relative_to(FTP_UPLOAD_DIR)
        s3_key = f"{S3_PREFIX}{relative_path}"

        upload_to_s3(local_path, s3_key)

    def on_incomplete_file_sent(self, file):
        """Called when file transmission is incomplete."""
        logger.warning(f"Incomplete file sent: {file}")

    def on_incomplete_file_received(self, file):
        """Called when file reception is incomplete."""
        logger.warning(f"Incomplete file received: {file}")


def setup_ftp_server():
    """Setup and configure the FTP server."""

    # Create upload directory if it doesn't exist
    FTP_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    # Instantiate a dummy authorizer for managing 'virtual' users
    authorizer = DummyAuthorizer()

    # Define a new user with full permissions
    authorizer.add_user(
        FTP_USER,
        FTP_PASSWORD,
        str(FTP_UPLOAD_DIR.absolute()),
        perm=FTP_PERMISSIONS
    )

    # Instantiate FTP handler class
    handler = CustomFTPHandler
    handler.authorizer = authorizer

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
    logger.info(f"Username: {FTP_USER}")
    logger.info(f"Max connections: {FTP_MAX_CONS}")
    logger.info(f"Max connections per IP: {FTP_MAX_CONS_PER_IP}")
    logger.info("")
    if S3_BUCKET:
        logger.info(f"S3 Upload: ENABLED")
        logger.info(f"S3 Bucket: {S3_BUCKET}")
        logger.info(f"S3 Region: {S3_REGION}")
        logger.info(f"S3 Prefix: {S3_PREFIX}")
    else:
        logger.warning("S3 Upload: DISABLED (S3_BUCKET not configured)")
        logger.warning("Files will remain in local temporary directory")
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
