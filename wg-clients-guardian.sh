#!/bin/bash
# This script is written by Alfio Salanitri <www.alfiosalanitri.it> and are licensed under MIT License.
# Credits: This script is inspired to https://github.com/pivpn/pivpn/blob/master/scripts/wireguard/clientSTAT.sh

# config variables
current_path=$(pwd)
clients_directory="$current_path/clients"
now=$(date +%s)

# after X minutes the clients will be considered disconnected
timeout=15

# check if wireguard exists
if ! command -v wg &> /dev/null; then
	printf "Sorry, but wireguard is required. Install it with before.\n"
	exit 1;
fi
wireguard_clients=$(wg show wg0 dump | tail -n +2) # remove first line from list
if [ "" == "$wireguard_clients" ]; then
	printf "No wireguard clients.\n"
	exit 1
fi

# check if the user type the telegram config file and that file exists
if [ ! "$1" ]; then
	printf "The config file with telegram chat id and bot token is required\n"
	exit 1
fi
if [ ! -f "$1" ]; then
	printf "This config file doesn't exists\n"
	exit 1
fi
telegram_chat_id=$(awk -F'=' '/^chat=/ { print $2}' $1)
telegram_token=$(awk -F'=' '/^token=/ { print $2}' $1)

while IFS= read -r LINE; do
	public_key=$(awk '{ print $1 }' <<< "$LINE")
	remote_ip=$(awk '{ print $3 }' <<< "$LINE" | awk -F':' '{print $1}')
	last_seen=$(awk '{ print $5 }' <<< "$LINE")
	client_name=$(grep -R "$public_key" /etc/wireguard/keys/ | awk -F"/etc/wireguard/keys/|_pub:" '{print $2}' | sed -e 's./..g')
	client_file="$clients_directory/$client_name.txt"

	# create the client file if not exists.
	if [ ! -f "$client_file" ]; then
		echo "offline" > $client_file
	fi	

	# setup notification variable
	send_notification="no"
	  
	# last client status
	last_connection_status=$(cat $client_file)
	  
	# elapsed seconds from last connection
	last_seen_seconds=$(date -d @"$last_seen" '+%s')
	
	# it the user is online
	if [ "$last_seen" -ne 0 ]; then

		# elaped minutes from last connection
		last_seen_elapsed_minutes=$((10#$(($now - $last_seen_seconds)) / 60))

		# if the previous state was online and the elapsed minutes are greater then timeout, the user is offline
		if [ $last_seen_elapsed_minutes -gt $timeout ] && [ "online" == $last_connection_status ]; then
			echo "offline" > $client_file
			send_notification="disconnected"
			# if the previous state was offline and the elapsed minutes are lower then timout, the user is online
		elif [ $last_seen_elapsed_minutes -le $timeout ] && [ "offline" == $last_connection_status ]; then
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
		message="🐉 Wireguard: \`$client_name is $send_notification from ip address $remote_ip\`"
		curl -s -X POST "https://api.telegram.org/bot${telegram_token}/sendMessage" -F chat_id=$telegram_chat_id -F text="$message" -F parse_mode="MarkdownV2" > /dev/null 2>&1
	else
		printf "The client %s is %s, no notification will be send.\n" $client_name $(cat $client_file)
	fi

done <<< "$wireguard_clients"

exit 0
