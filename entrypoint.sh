#!/bin/sh
set -e

# Path to the final configuration file
CONF_FILE="/etc/keepalived/keepalived.conf"
PID_FILE="/var/run/keepalived.pid"

echo "--- Keepalived Startup Process ---"

# 1. Cleanup stale PID file if any from persistent volumes
if [ -f "$PID_FILE" ]; then
    echo "INFO: Cleaning up stale PID file at $PID_FILE..."
    rm -f "$PID_FILE"
fi

# 2. Check if a custom configuration file exists (it could be a file or a symlink)
if [ -e "$CONF_FILE" ]; then
    echo "INFO: Configuration detected at $CONF_FILE. Skipping auto-generation."
else
    # Generate a basic configuration using environment variables if no file is provided
    echo "INFO: No custom config detected. Generating configuration from environment variables..."
    
    # Set default values if variables are not provided by Docker Compose/Environment
    STATE=${STATE:-MASTER}
    PRIORITY=${PRIORITY:-100}
    INTERFACE="${MYIF:-${INTERFACE:-eth0}}"
    ROUTER_ID=${ROUTER_ID:-51}
    VIRTUAL_IP=${VIRTUAL_IP:-192.168.1.1}

    # Create the configuration file using a Here-Doc
    cat <<EOF > $CONF_FILE
vrrp_instance VI_1 {
    state $STATE
    interface $INTERFACE
    virtual_router_id $ROUTER_ID
    priority $PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        $VIRTUAL_IP
    }
}
EOF
    echo "INFO: Basic configuration generated successfully."
fi

# 3. Wait for network interface readiness
# Prioritize MYIF (common in this stack) over INTERFACE, default to eth0
WAIT_IF="${MYIF:-${INTERFACE:-eth0}}"

echo "INFO: Waiting for interface $WAIT_IF to be UP..."
MAX_TRIES=30
TRIES=0
while ! ip link show "$WAIT_IF" | grep -q "UP,LOWER_UP" && [ $TRIES -lt $MAX_TRIES ]; do
    sleep 1
    TRIES=$((TRIES + 1))
    if [ $((TRIES % 10)) -eq 0 ]; then
        echo "Still waiting for $WAIT_IF ($TRIES/$MAX_TRIES)..."
    fi
done

if ! ip link show "$WAIT_IF" | grep -q "UP,LOWER_UP"; then
    echo "WARNING: Interface $WAIT_IF is not fully UP after $MAX_TRIES seconds. Keepalived might fail."
fi

# 4. Start Keepalived in foreground
echo "INFO: Launching Keepalived binary..."
exec /usr/sbin/keepalived -f "$CONF_FILE" --dont-fork --log-console --log-detail
