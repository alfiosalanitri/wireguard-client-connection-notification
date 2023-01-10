# wireguard-client-connection-notification
Send a message to Telegram or Gotify Server when a client is connected or disconnected from wireguard tunnel

## How to use:
- Clone this repo into your server with wireguard installed
- Rename .config.example to .config and edit the file
- Make sure to add it to the root user's cron as elevated privileges are required to view the tunnel info.
- Open the terminal and type:
  - `sudo -s`
  - `chmod +x /path/to/wireguard-client-connection-notification/wg-clients-guardian`
  - `cp .config-example .config`
  - `sudo crontab -e`
  - `* * * * * cd /path/to/wireguard-client-connection-notification && /path/to/wireguard-client-connection-notification/wg-clients-guardian /path/to/wireguard-client-connection-notification/.config > /dev/null 2>&1`