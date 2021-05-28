#!/bin/bash

#Author: www.alfiosalanitri.it
#Credits: This script is inspired to https://github.com/pivpn/pivpn/blob/master/scripts/wireguard/clientSTAT.sh

#Config variable
CURRENT_PATH="$("pwd")"
CLIENTS_FILE="/etc/wireguard/configs/clients.txt"
CLIENTS_CONNECTION_PATH="$CURRENT_PATH/clients"

# current time
NOW=$(date +%s)

# after x minutes of inactivity the clients is disconnected.
TIME_LIMIT=15

#telegram section
TELEGRAM_CHAT_ID="your-chat-id"
TELEGRAM_BOT_ID="your-bot-api-key"

# no wireguard clients, exit.
if [ ! -s "$CLIENTS_FILE" ]; then
    exit 1
fi

# human readable bytes
hr(){
    numfmt --to=iec-i --suffix=B "$1"
}

# cicle all clients
listClients(){
    if DUMP="$(wg show wg0 dump)"; then
        DUMP="$(tail -n +2 <<< "$DUMP")"
    else
        exit 1
    fi

    {
    
	#printf "\e[4mName\e[0m  \t  \e[4mRemote IP\e[0m  \t  \e[4mVirtual IP\e[0m  \t  \e[4mBytes Received\e[0m  \t  \e[4mBytes Sent\e[0m  \t  \e[4mLast Seen\e[0m\n"

    while IFS= read -r LINE; do

        PUBLIC_KEY="$(awk '{ print $1 }' <<< "$LINE")"
        REMOTE_IP="$(awk '{ print $3 }' <<< "$LINE")"
        VIRTUAL_IP="$(awk '{ print $4 }' <<< "$LINE")"
        BYTES_RECEIVED="$(awk '{ print $6 }' <<< "$LINE")"
        BYTES_SENT="$(awk '{ print $7 }' <<< "$LINE")"
        LAST_SEEN="$(awk '{ print $5 }' <<< "$LINE")"
        CLIENT_NAME="$(grep "$PUBLIC_KEY" "$CLIENTS_FILE" | awk '{ print $1 }')"
	CLIENT_CONNECTION_FILE="$CLIENTS_CONNECTION_PATH/$CLIENT_NAME.txt"

	# first time, create the client file
	if [ ! -f "$CLIENT_CONNECTION_FILE" ]; then
	  echo "offline" > $CLIENT_CONNECTION_FILE
	fi	

	# default, no notification if there aren't changes
	SEND_NOTIFICATION="no"

	# last client connection status saved in txt file inside clients folder
	LAST_CONNECTION_STATUS=$(cat $CLIENT_CONNECTION_FILE)

	# seconds elapsed from last seen
	LAST_SEEN_SECONDS=$(date -d @"$LAST_SEEN" '+%s')
	
	# if the client is connected
	if [ "$LAST_SEEN" -ne 0 ]; then
		#printf "%s  \t  %s  \t  %s  \t  %s  \t  %s  \t  %s\n" "$CLIENT_NAME" "$REMOTE_IP" "${VIRTUAL_IP/\/32/}" "$(hr "$BYTES_RECEIVED")" "$(hr "$BYTES_SENT")" "$(date -d @"$LAST_SEEN" '+%b %d %Y - %T')"

		# calculate the minutes elapsed from last seen
		LAST_SEEN_ELAPSED_MINUTES=$((10#$(($NOW - $LAST_SEEN_SECONDS)) / 60))
		
		# if the minutes are greather then time limit and the last status is online, the client is disconnected because
		# there aren't activity
		if [ $LAST_SEEN_ELAPSED_MINUTES -gt $TIME_LIMIT ] && [ "online" == $LAST_CONNECTION_STATUS ]; then
			echo "offline" > $CLIENT_CONNECTION_FILE
			SEND_NOTIFICATION="disconnected"

		# if the minutes are less or equal to time limit, the client is connected.
		elif [ $LAST_SEEN_ELAPSED_MINUTES -le $TIME_LIMIT ] && [ "offline" == $LAST_CONNECTION_STATUS ]; then
		
			echo "online" > $CLIENT_CONNECTION_FILE
			SEND_NOTIFICATION="connected"
		fi
	else
		#printf "%s  \t  %s  \t  %s  \t  %s  \t  %s  \t  %s\n" "$CLIENT_NAME" "$REMOTE_IP" "${VIRTUAL_IP/\/32/}" "$(hr "$BYTES_RECEIVED")" "$(hr "$BYTES_SENT")" "(not yet)"
		# if the last seen is zero, send notification only if the last status is online in the file txt
		if [ "offline" != $LAST_CONNECTION_STATUS ]; then
			echo "offline" > $CLIENT_CONNECTION_FILE
			SEND_NOTIFICATION="disconnected"
		fi
	fi

	# send the notification only if the variable is rewritten
	if [ "no" != $SEND_NOTIFICATION ]; then
		MESSAGE="🐉 Wireguard: \`$CLIENT_NAME $SEND_NOTIFICATION from $REMOTE_IP\`"
		curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_ID}/sendMessage" -F chat_id=$TELEGRAM_CHAT_ID -F text="$MESSAGE" -F parse_mode="MarkdownV2" > /dev/null 2>&1
	fi


    done <<< "$DUMP"

    printf "\n"
    } |column -t -s $'\t'
}

#start the script
listClients
exit 1
