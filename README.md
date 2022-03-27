# wireguard-client-connection-notification
Send a message to telegram when a client is connected or disconnected from wireguard tunnel

## How to use:
- Clone this repo into your server with wireguard installed
- Rename .config.example to .config and edit the file with your telegram chat id and bot token
- Open the terminal and type:
  - `sudo -s`
  - `chmod +x /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh`
  - `crontab -e`
  - `* * * *  * cd  /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh && /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh /path/to/wireguard-client-connection-notification/.config > /dev/null 2>&1`
