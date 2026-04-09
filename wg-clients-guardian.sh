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

readonly WGDASHBOARD_API_URL=$(awk -F'=' '/^wgdashboard_api_url=/ { print $2}' $1)
readonly WGDASHBOARD_API_KEY=$(awk -F'=' '/^wgdashboard_api_key=/ { print $2}' $1)
readonly WGDASHBOARD_API_TTL=$(awk -F'=' '/^wgdashboard_api_ttl=/ { print $2}' $1 || echo "86400") # default 24 hours
readonly WGDASHBOARD_API_RETRY_COUNT=$(awk -F'=' '/^wgdashboard_api_retry_count=/ { print $2}' $1 || echo "3") # default 3 retries
readonly WGDASHBOARD_API_RETRY_SLEEP=$(awk -F'=' '/^wgdashboard_api_retry_sleep=/ { print $2}' $1 || echo "5") # default 5 second
readonly WGDASHBOARD_API_CACHE_FILE="$CLIENTS_DIRECTORY/.api_cache"

# Function to get cached API response if available and not expired
get_cached_api_response() {
	if [ -f "$WGDASHBOARD_API_CACHE_FILE" ]; then
		local cache_timestamp=$(head -1 "$WGDASHBOARD_API_CACHE_FILE")
		local current_time=$(date +%s)
		local age=$((current_time - cache_timestamp))
		
		if [ $age -lt $WGDASHBOARD_API_TTL ]; then
			sed '1d' "$WGDASHBOARD_API_CACHE_FILE"
			return 0
		fi
	fi
	return 1
}

# Function to cache API response with timestamp
cache_api_response() {
	local response="$1"
	local timestamp=$(date +%s)
	{
		echo "${timestamp}"
		echo "$response"
	} > "$WGDASHBOARD_API_CACHE_FILE"
}

# Function to fetch API response with retry logic
fetch_wgdashboard_api() {
	local retry=0
	local response=""
	local peers_data=""
	
	# Check if jq is available first
	if ! command -v jq &> /dev/null; then
		return 1
	fi
	
	if ! command -v curl &> /dev/null; then
		return 1
	fi

	while [ $retry -lt $WGDASHBOARD_API_RETRY_COUNT ]; do
		response=$(curl -s -H "wg-dashboard-apikey: $WGDASHBOARD_API_KEY" "$WGDASHBOARD_API_URL/api/getWireguardConfigurationInfo?configurationName=wg0" 2>/dev/null)

		if [ -n "$response" ]; then
			# Extract only id and name from configurationPeers (one JSON object per line, compact format)
			peers_data=$(echo "$response" | jq -c '.data.configurationPeers[] | {id, name}' 2>/dev/null)
			
			if [ -n "$peers_data" ]; then
				cache_api_response "$peers_data"
				echo "$peers_data"
				return 0
			fi
		fi
		
		retry=$((retry + 1))
		if [ $retry -lt $WGDASHBOARD_API_RETRY_COUNT ]; then
			sleep "$WGDASHBOARD_API_RETRY_SLEEP"
		fi
	done
	
	return 1
}

# Try wgdashboard API if configured
if [ -n "$WGDASHBOARD_API_URL" ] && [ -n "$WGDASHBOARD_API_KEY" ]; then
	# Try to get cached response first
	api_response=$(get_cached_api_response)
	
	# If cache is expired or missing, fetch from API with retries
	if [ -z "$api_response" ]; then
		api_response=$(fetch_wgdashboard_api)
	fi
fi

while IFS= read -r LINE; do
	public_key=$(awk '{ print $1 }' <<< "$LINE")
	remote_ip=$(awk '{ print $3 }' <<< "$LINE" | awk -F':' '{print $1}')
	last_seen=$(awk '{ print $5 }' <<< "$LINE")
	# By default, the client name is just the sanitized public key containing only letters and numbers.
	client_name=$(echo "$public_key" | sed 's/[^a-zA-Z0-9]//g')
	client_name_by_public_key=""
	# check if the wireguard directory keys exists (created by pivpn)
	if [ -d "/etc/wireguard/keys/" ]; then
		# if the public_key is stored in the /etc/wireguard/keys/username_pub file, save the username in the client_name var
		client_name_by_public_key=$(grep -R "$public_key" /etc/wireguard/keys/ | awk -F"/etc/wireguard/keys/|_pub:" '{print $2}' | sed -e 's./..g')
		if [ "" != "$client_name_by_public_key" ]; then
			client_name=$client_name_by_public_key
		fi
	else
		# if client_name_by_public_key is empty, try to look up in wgdashboard via API (preferred)
		if [ -z "$client_name_by_public_key" ]; then
			if [ -n "$api_response" ]; then
				# Search through cached peers data (one JSON object per line)
				client_name_by_public_key=$(echo "$api_response" | grep "$public_key" | jq -r '.name' 2>/dev/null)
				if [ -n "$client_name_by_public_key" ]; then
					client_name=$client_name_by_public_key
				fi
			fi
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
