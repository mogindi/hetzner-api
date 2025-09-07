#!/bin/bash


. .env

curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/server -s | jq
