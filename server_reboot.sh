#!/bin/bash

. .env

if ! [ "$#" -eq 1 ]; then
        echo "Incorrect argument count."
        echo "Please enter [ SERVER NUMBER ] as argument"
        exit 1
fi


server_number=$1

echo $server_number: Rebooting into main OS..
curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/reset/$server_number \
        -d type=hw \
        -s | jq .

sleep 10


# We wait for ssh to be reachable (redeployment complete)

while ! (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
        echo "$server_number: Failed tcp connection to $ip:$port. Trying again.."
        sleep 5
done

echo $server_number: Node ready
