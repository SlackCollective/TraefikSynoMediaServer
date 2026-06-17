#!/bin/bash
# iptables.sh — wait for Docker's DOCKER-USER chain to exist at boot, then add NAT rules
# so locally-originated connections to the NAS's own LAN IP on a published Docker port
# get hairpinned to the container. Register as a DSM Task Scheduler "Triggered Task"
# (Event: Boot-up, User: root). Idempotent: safe to run any time (checks before adding).
#
# Note: this does NOT make 127.0.0.1/localhost:<port> work from the host itself — that
# additionally requires net.ipv4.conf.*.route_localnet=1, which is 0 on this NAS by
# default, so loopback-sourced packets to the docker bridge get dropped as martian
# before they reach the container. Use the NAS's LAN IP instead of localhost for any
# host-side script that needs to reach a published port (see scripts/.env.example).

currentAttempt=0
totalAttempts=10
delay=15
sleep 60
while [ $currentAttempt -lt $totalAttempts ]
do
	currentAttempt=$(( $currentAttempt + 1 ))

	echo "Attempt $currentAttempt of $totalAttempts..."

	result=$(iptables-save)

	if [[ $result =~ "DOCKER-USER" ]]; then
		echo "Docker rules found! Modifying..."

		iptables -t nat -C PREROUTING ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER 2>/dev/null || \
			iptables -t nat -A PREROUTING ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
		iptables -t nat -C OUTPUT -m addrtype --dst-type LOCAL -j DOCKER 2>/dev/null || \
			iptables -t nat -A OUTPUT -m addrtype --dst-type LOCAL -j DOCKER

		echo "Done!"

		break
	fi

	echo "Docker rules not found! Sleeping for $delay seconds..."

	sleep $delay
done
