#!/bin/bash
# Send a message to Telegram or Gotify Server when a client is connected or disconnected from wireguard tunnel
#
#
# This script is written by Alfio Salanitri <www.alfiosalanitri.it> and are licensed under MIT License.
# Credits: This script is inspired by https://github.com/pivpn/pivpn/blob/master/scripts/wireguard/clientSTAT.sh

# check if wireguard exists
if ! command -v wg &> /dev/null; then
	printf "Sorry, but wireguard is required. Install it and try again.\n"
	exit 1;
fi

# check if the user passed in the config file and that the file exists
if [ ! "$1" ]; then
	printf "The config file is required.\n"
	exit 1
fi
if [ ! -f "$1" ]; then
	printf "This config file doesn't exist.\n"
	exit 1
fi

# config constants
readonly CURRENT_PATH=$(pwd)
readonly CLIENTS_DIRECTORY="$CURRENT_PATH/clients"
readonly NOW=$(date +%s)

# after X minutes the clients will be considered disconnected
readonly TIMEOUT=$(awk -F'=' '/^timeout=/ { print $2}' $1)

readonly WIREGUARD_CLIENTS=$(wg show wg0 dump | tail -n +2) # remove first line from list
if [ "" == "$WIREGUARD_CLIENTS" ]; then
	printf "No wireguard clients.\n"
	exit 1
fi

readonly NOTIFICATION_CHANNEL=$(awk -F'=' '/^notification_channel=/ { print $2}' $1)

readonly GOTIFY_HOST=$(awk -F'=' '/^gotify_host=/ { print $2}' $1)
readonly GOTIFY_APP_TOKEN=$(awk -F'=' '/^gotify_app_token=/ { print $2}' $1)
readonly GOTIFY_TITLE=$(awk -F'=' '/^gotify_title=/ { print $2}' $1)

readonly TELEGRAM_CHAT_ID=$(awk -F'=' '/^chat=/ { print $2}' $1)
readonly TELEGRAM_TOKEN=$(awk -F'=' '/^token=/ { print $2}' $1)

while IFS= read -r LINE; do
	public_key=$(awk '{ print $1 }' <<< "$LINE")
	remote_ip=$(awk '{ print $3 }' <<< "$LINE" | awk -F':' '{print $1}')
	last_seen=$(awk '{ print $5 }' <<< "$LINE")
	# By default, the client name is just the sanitized public key containing only letters and numbers.
	client_name=$(echo "$public_key" | sed 's/[^a-zA-Z0-9]//g')
	# check if the wireguard directory keys exists (created by pivpn)
	if [ -d "/etc/wireguard/keys/" ]; then
		# if the public_key is stored in the /etc/wireguard/keys/username_pub file, save the username in the client_name var
		client_name_by_public_key=$(grep -R "$public_key" /etc/wireguard/keys/ | awk -F"/etc/wireguard/keys/|_pub:" '{print $2}' | sed -e 's./..g')
		if [ "" != "$client_name_by_public_key" ]; then
			client_name=$client_name_by_public_key
		fi
	fi
	client_file="$CLIENTS_DIRECTORY/$client_name.txt"

	# create the client file if it does not exist.
	if [ ! -f "$client_file" ]; then
		echo "offline" > $client_file
	fi

	# setup notification variable
	send_notification="no"

	# last client status
	last_connection_status=$(cat $client_file)

	# elapsed seconds from last connection
	last_seen_seconds=$(date -d @"$last_seen" '+%s')

	# if the user is online
	if [ "$last_seen" -ne 0 ]; then

		# elapsed minutes from last connection
		last_seen_elapsed_minutes=$((10#$(($NOW - $last_seen_seconds)) / 60))

		# if the previous state was online and the elapsed minutes are greater than TIMEOUT, the user is offline
		if [ $last_seen_elapsed_minutes -gt $TIMEOUT ] && [ "online" == $last_connection_status ]; then
			echo "offline" > $client_file
			send_notification="disconnected"
		# if the previous state was offline and the elapsed minutes are lower than timout, the user is online
		elif [ $last_seen_elapsed_minutes -le $TIMEOUT ] && [ "offline" == $last_connection_status ]; then
			echo "online" > $client_file
			send_notification="connected"
		fi
	else
		# if the user is offline
		if [ "offline" != "$last_connection_status" ]; then
			echo "offline" > $client_file
			send_notification="disconnected"
		fi
	fi

	# send notification to telegram
	if [ "no" != "$send_notification" ]; then
		printf "The client %s is %s\n" $client_name $send_notification
		message="$client_name is $send_notification from ip address $remote_ip"
		if [ "telegram" == "$NOTIFICATION_CHANNEL" ] || [ "both" == "$NOTIFICATION_CHANNEL" ]; then
			curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" -F chat_id=$TELEGRAM_CHAT_ID -F text="🐉 Wireguard: \`$message\`" -F parse_mode="MarkdownV2" > /dev/null 2>&1
		fi
		if [ "gotify" == "$NOTIFICATION_CHANNEL" ] || [ "both" == "$NOTIFICATION_CHANNEL" ]; then
			curl -X POST "${GOTIFY_HOST}/message" -H "accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${GOTIFY_APP_TOKEN}" -d '{"message": "'"$message"'", "priority": 5, "title": "'"$GOTIFY_TITLE"'"}' > /dev/null 2>&1
		fi
	else
		printf "The client %s is %s, no notification will be sent.\n" $client_name $(cat $client_file)
	fi

done <<< "$WIREGUARD_CLIENTS"

exit 0
