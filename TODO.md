- upload entire video stream ?
    - You can use HTTP requests to grab live JPEG snapshots, which can then be saved by your HTTP client or server. 
    Enable Ports: Ensure HTTP or HTTPS is enabled in the Reolink Client.
    
    Snapshot URL Structure: You can typically capture a snapshot using an HTTP GET request like:
    http://<IP of the camera>:<HTTP port>/cgi-bin/api.cgi?cmd=Snap&channel=0&user=<username>&password=<password>
    
    Live Stream (FLV): You can also get a live video stream in FLV format via browser:
    http://<IP of the camera>:<HTTP port>/flv?port=1935&app=bcs&stream=channel0_main.bcs&user=<username>&password=<password>. 