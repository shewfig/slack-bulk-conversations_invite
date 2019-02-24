#!/bin/bash

# Arg 1: token
# ARG 2: channel
# Args 2-n: user email addresses

# settings
URL_base="https://slack.com/api/"
API_email="users.lookupByEmail"
API_invite="conversations.invite"

function usage
{
	cat <<EOUSE
Usage:
	$0 API_TOKEN CHANNEL email-1 [ ...email_n ]
EOUSE
}

LOGTIME=$(date "+%Y%m%d%H%M%S")
LOGGOOD="${LOGTIME}_good.txt"
LOGBAD="${LOGTIME}_bad.txt"

function log_good
{
	echo "$@" >> $LOGGOOD
}

function log_bad
{
	echo "$@" >> $LOGBAD
}

done_good=0
done_bad=0

if [ $# -lt 3 ]; then
	log_bad "ERROR: $@" 
	usage
	exit 1
fi

log_good "Starting at $(date)"

API_TOKEN="${1}"
log_good "Found token"
shift

CHANNEL="${1}"
log_good "Channel: $CHANNEL"
shift

#echo "Token: ${API_TOKEN}"

# find chanID from channel name
chanListQ="${URL_base}conversations.list?token=${API_TOKEN}&exclude_archived=true&types=public_channel,private_channel"
chanList=$(curl -s -X GET "${chanListQ}")
log_good "$(echo "$chanList" | jq '.channels[] | select ( .name == "'$CHANNEL'" ) | "\(.name) \(.id) \(.purpose.value)"')"
chanID=$(echo "$chanList" | jq '.channels[] | select ( .name == "'$CHANNEL'" ) | "\(.id)"')
chanID=$(echo ${chanID} | sed -e 's/"//g')
log_good "ChanID: ${chanID}"

# iterate through emails, extract UID from email, invite to chanID
regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
until [ -z "$1" ]; do

	# next email address
	email_addr="${1}"
	shift
	
	# test if it looks valid
	if ! [[ $email_addr =~ $regex ]]; then
		log_bad "${email_addr}: BAD_ADDRESS"
		let "done_bad += 1"
	else
		# find UID by email
		myquery="${URL_base}${API_email}?token=${API_TOKEN}&email=${email_addr}"
		myfound=$(curl -s -X GET ${myquery})
		if [ $(echo $myfound | jq '.ok') == "true" ]; then
			myname=$(echo "$myfound" | jq '.user.name')
			myUID=$(echo "$myfound" | jq '.user.id')
			myUID=$(echo ${myUID} | sed -e 's/"//g')
			#log_good "$email_addr is $myname ($myUID)"
			#echo "$myfound" | jq '.'
			#echo "Press ENTER to continue"
			#read
			inviteQuery="${URL_base}${API_invite}?token=${API_TOKEN}&channel=${chanID}&users=${myUID}"
			#echo ${inviteQuery}
			inviteRV=$(curl -s -X GET ${inviteQuery})
			if [ $( echo ${inviteRV} | jq '.ok') = "true" ]; then
				#log_good "${email_addr}: $inviteRV"
				log_good "${email_addr} ($myUID): added to ${CHANNEL} (${chanID})"
				let "done_good += 1"
			else
				log_bad "${email_addr} (${myUID}): $inviteRV $inviteQuery"
				let "done_bad += 1"
			fi
		else
			log_bad "$email_addr: ${myfound}"
			let "done_bad += 1"
		fi
	fi
done

echo "Good: $done_good"
echo "Bad $done_bad"
