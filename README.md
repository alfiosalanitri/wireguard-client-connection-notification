# WireGuard Client Connection Notification

Receive notifications via Telegram or Gotify whenever a client connects or disconnects from a WireGuard tunnel.

## Installation and Setup

Follow these steps to set up the notification service on your WireGuard server.

### 1. Clone the Repository

Start by cloning this repository onto your server:

```bash
git clone https://github.com/yourusername/wireguard-client-connection-notification.git
```

### 2. Configure the Service

1. Rename the configuration file template:

   ```bash
   mv .config-example .config
   ```

2. Edit the `.config` file to include your notification settings. Make sure to configure either Telegram or Gotify server details.

### 3. Set Up Permissions and Schedule the Script

1. Grant execution permissions to the main script:

   ```bash
   sudo chmod +x /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh
   ```

2. Add the script to the root user's cron job to run it periodically. Elevated privileges are required to access WireGuard tunnel information.

   - Open the root crontab editor:

     ```bash
     sudo crontab -e
     ```

   - Add the following line to execute the script every minute:

     ```bash
     * * * * * cd /path/to/wireguard-client-connection-notification && /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh /path/to/wireguard-client-connection-notification/.config > /dev/null 2>&1
     ```

### 4. Start Receiving Notifications

Once everything is set up, the script will check for client connections or disconnections every minute and send a notification through your configured method.

## Acknowledgements

This project was inspired by and built upon the work done by the [PiVPN](https://github.com/pivpn/pivpn) project. Special thanks to the PiVPN team for their `clientSTAT.sh` script, which served as a foundation for understanding and managing WireGuard client connections. You can find the original script [here](https://github.com/pivpn/pivpn/blob/master/scripts/wireguard/clientSTAT.sh).