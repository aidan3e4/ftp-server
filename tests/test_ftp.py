#!/usr/bin/env python3
from ftplib import FTP
import sys

try:
    # Connect to FTP server
    ftp = FTP()
    print("Connecting to localhost:2121...")
    ftp.connect('localhost', 2121, timeout=10)
    print(f"Response: {ftp.getwelcome()}")

    # Login
    print("Logging in as reolink...")
    ftp.login('reolink', 'camera123')
    print("Login successful!")

    # Create a test file
    with open('/tmp/test_upload.txt', 'rb') as f:
        print("Uploading test file...")
        ftp.storbinary('STOR test_upload.txt', f)
        print("Upload successful!")

    # List files
    print("\nFiles on server:")
    ftp.retrlines('LIST')

    # Quit
    ftp.quit()
    print("\nTest completed successfully!")
    sys.exit(0)

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
