#!/bin/bash
# Kali static IP configuration via NetworkManager
# Run with: sudo bash kali-static-ip.sh
#
# Note: confirm the actual connection profile name first with
# `nmcli con show` — this assumes the default Kali profile name.

CONN_NAME="Wired connection 1"

nmcli con mod "$CONN_NAME" ipv4.addresses 10.0.0.30/24
nmcli con mod "$CONN_NAME" ipv4.gateway 10.0.0.1
nmcli con mod "$CONN_NAME" ipv4.dns "10.0.0.10"
nmcli con mod "$CONN_NAME" ipv4.method manual
nmcli con mod "$CONN_NAME" connection.autoconnect yes
nmcli con up "$CONN_NAME"

# Verify:
# ip a
# ip route show
# ping -c 4 8.8.8.8
