# wireguard-client-connection-notification
Send a message to telegram when a client is connected or disconnected from wireguard tunnel

## How to use:
- Clone this repo into your server with wireguard installed
- Change this config option values from wg-clients-guardian.sh:
  - TELEGRAM_CHAT_ID="your-chat-id"
  - TELEGRAM_BOT_ID="your-bot-api-key"
- Open the terminal and type:
  - `sudo -s`
  - `chmod +x /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh`
  - `crontab -e`
  - `*/5 * * *  * cd  /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh && /path/to/wireguard-client-connection-notification/wg-clients-guardian.sh > /dev/null 2>&1`
