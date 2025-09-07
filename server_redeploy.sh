#!/bin/bash

#set -xe

. .env

if ! [ "$#" -eq 1 ]; then
	echo "Incorrect argument count."
	echo "Please enter [ SERVER NUMBER ] as argument"
	exit 1
fi


server_number=$1

linux_distribution="Ubuntu 22.04.2 LTS base"

echo Applying installation configurations..

curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/boot/$server_number/linux \
	-d "dist=$linux_distribution&lang=en&authorized_key[]=$SSH_FINGERPRINT" \
	-s | jq .

echo Rebooting to start installation..

curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/reset/$server_number \
	-d type=hw \
	-s | jq .

# wait a few seconds to make sure it shutsdown

sleep 5


echo Waiting for node to come online..

ip=$(curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/server/$server_number -s | jq .server.ip[0] -r)
port=22

# We wait for ssh to be reachable (rescue mode)

while ! (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
        echo "Failed tcp connection to $ip:$port. Trying again.."
        sleep 5
done


# We wait for it NOT BE REACHABLE (another reboot)

while (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
        echo "Succeeded tcp connection to $ip:$port, but its probably in rescue mode. Waiting.."
        sleep 5
done


# We wait for ssh to be reachable (redeployment complete)

while ! (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
        echo "Failed tcp connection to $ip:$port. Trying again.."
        sleep 5
done

echo Node ready
