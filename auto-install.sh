#!/usr/bin/env bash
set -e

log() { echo -e "[+] $*"; }

log "Updating packages..."
apt update -y

log "Installing requirements..."
apt install -y curl git openssh-server autossh

# Ensure sshd is running
if ! pgrep -x "sshd" >/dev/null 2>&1; then
    log "Starting SSH server..."
    service ssh start || systemctl start ssh || true
fi

USER_TO_USE="${SUDO_USER:-$USER}"
LOGFILE="/tmp/serveo_tunnel.log"

log "Creating reverse tunnel via serveo.net..."
nohup ssh -o "ExitOnForwardFailure=yes" \
     -o "ServerAliveInterval=30" \
     -o "ServerAliveCountMax=3" \
     -o "StrictHostKeyChecking=no" \
     -R 0:localhost:22 serveo.net -N -v >"$LOGFILE" 2>&1 &

SSH_PID=$!
log "Tunnel process started (PID: $SSH_PID). Waiting for port allocation..."

# Wait for port allocation
ALLOCATED=""
for i in {1..20}; do
    if grep -q "Allocated port" "$LOGFILE" 2>/dev/null; then
        ALLOCATED=$(grep "Allocated port" "$LOGFILE" | tail -n1 | sed -E 's/.*Allocated port ([0-9]+).*/\1/')
        break
    fi
    if grep -qiE "listening on .*port [0-9]+" "$LOGFILE" 2>/dev/null; then
        ALLOCATED=$(grep -iE "listening on .*port [0-9]+" "$LOGFILE" | tail -n1 | sed -E 's/.*port ([0-9]+).*/\1/')
        break
    fi
    sleep 1
done

if [ -z "$ALLOCATED" ]; then
    log "❌ Could not get allocated port. Check log: $LOGFILE"
    tail -n 20 "$LOGFILE" || true
    exit 1
fi

cat <<EOF

✅ Tunnel established!

Connect to this machine using:

  ssh -p $ALLOCATED $USER_TO_USE@serveo.net

(Use your local SSH password or key)

Tunnel PID : $SSH_PID
Logs       : $LOGFILE

EOF
