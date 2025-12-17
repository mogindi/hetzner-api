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

echo $server_number: Applying rescue boot command..
curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/boot/$server_number/rescue \
	-d "os=linux&authorized_key[]=$SSH_FINGERPRINT" \
	-s | jq .

echo $server_number: Rebooting into rescue..
curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/reset/$server_number \
	-d type=hw \
	-s | jq .

# wait a few seconds to make sure it shuts down

sleep 10


echo $server_number: Waiting for node to come online..
ip=$(curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/server/$server_number -s | jq .server.ip[0] -r)
port=22

# We wait for ssh to be reachable (rescue mode)

while ! (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
        echo "$server_number: Failed tcp connection to $ip:$port. Trying again.."
        sleep 5
done


echo $server_number: Node reachable, probably rescue mode.

ssh-keygen -f ~/.ssh/known_hosts -R "$ip"
ssh-keyscan -t rsa $ip >> ~/.ssh/known_hosts

# Connect in rescue mode
# 1. Disable raid
# 2. Format disks
# 3. Write installimage config
# 4. Run installimage

ssh root@$ip bash -s <<EOF
set -x

mdadm --remove /dev/md/*
mdadm --stop /dev/md/*
wipefs -fa /dev/sd*

cat > yggdrasil_install <<EOT
DRIVE1 /dev/sda
BOOTLOADER grub
HOSTNAME hyper
PART swap swap 2G
PART /boot ext3 1024M
PART /     ext4 all
IMAGE /root/.oldroot/nfs/images/Ubuntu-2204-jammy-amd64-base.tar.gz
EOT

/root/.oldroot/nfs/install/installimage -c yggdrasil_install -a 
EOF

echo $server_number: Rebooting into main OS..
curl -u "$USERNAME":"$PASSWORD" https://robot-ws.your-server.de/reset/$server_number \
	-d type=hw \
	-s | jq .

sleep 10

## We wait for it NOT BE REACHABLE (another reboot)
#
#while (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
#        echo "$server_number: Succeeded tcp connection to $ip:$port, but its probably still in rescue mode. Waiting.."
#        sleep 5
#done


# We wait for ssh to be reachable (redeployment complete)

while ! (curl -m 5 $ip:$port -s -v 2>&1 | grep -q "Connected to"); do
        echo "$server_number: Failed tcp connection to $ip:$port. Trying again.."
        sleep 5
done

echo $server_number: Node ready
