#!/bin/bash
apt update -y
apt install -y git curl openssh

# Start SSH server if not running
if ! pgrep -x "sshd" > /dev/null; then
    echo "Starting SSH server..."
    service ssh start || systemctl start ssh
fi

# Create tunnel on Serveo
echo "Creating tunnel via serveo.net..."
ssh -o StrictHostKeyChecking=no -R 0:localhost:22 serveo.net
