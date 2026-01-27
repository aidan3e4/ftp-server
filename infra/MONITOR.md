# How to monitor the instance once deployed

You can view the deployment logs by SSH-ing into your EC2 instance. Here are the different logs available:

1. SSH into the Instance

`ssh -i /path/to/your-key.pem ec2-user@3.122.85.41`
or `$(terraform output -raw ssh_command)`

2. View Deployment Logs
Initial Setup/User Data Logs
This shows the deployment script that ran when the instance first started:
```bash
# View the complete setup log
sudo cat /var/log/user-data.log
```

```bash
# Or tail it to see the end
sudo tail -100 /var/log/user-data.log
```

FTP Service Logs (Real-time)
This is what you selected - shows the systemd service and Docker container logs:
```bash
# View recent logs
sudo journalctl -u ftp-server.service
```

```bash
# Follow logs in real-time
sudo journalctl -u ftp-server.service -f
```

```bash
# Show last 100 lines
sudo journalctl -u ftp-server.service -n 100
```

```bash
# Logs since last boot
sudo journalctl -u ftp-server.service -b
```

Direct Docker Container Logs

```bash
# View container logs
sudo docker logs ftp-server
```

```bash
# Follow logs in real-time
sudo docker logs -f ftp-server
```

```bash
# Last 100 lines with timestamps
sudo docker logs --tail 100 -t ftp-server
```

Check Service Status
```bash
# Check if service is running
sudo systemctl status ftp-server.service
```

```bash
# Check Docker containers
sudo docker ps
```

The most useful command for ongoing monitoring is:
```bash
sudo journalctl -u ftp-server.service -f
```

This will show you live logs from the FTP server, including connection attempts, file uploads, and any errors.