#!/bin/sh
set -e

# Enable debug if requested
if [ "$DEBUG" = "true" ]; then
    set -x
fi

# Path to the final configuration file
CONF_FILE="/etc/keepalived/keepalived.conf"
PID_FILE="/var/run/keepalived.pid"

echo "--- Keepalived Startup Process ---"

# 1. Cleanup stale PID file if any from persistent volumes
if [ -f "$PID_FILE" ]; then
    echo "INFO: Cleaning up stale PID file at $PID_FILE..."
    rm -f "$PID_FILE"
fi

# 2. Wait for configuration file (Docker Config/Volume race condition)
# If a config is expected via mount, it might not be ready right away on reboot
MAX_CONF_TRIES=10
CONF_TRIES=0
echo "--- Diagnostic: Pre-check ---"
echo "Current user: $(id)"
echo "Checking /etc/keepalived directory content:"
ls -la /etc/keepalived/ || echo "/etc/keepalived NOT found"
echo "Checking if a standalone /etc/keepalived.conf exists:"
ls -la /etc/keepalived.conf || echo "/etc/keepalived.conf NOT found"
echo "Active Keepalived environment variables:"
env | grep -E "KEEPALIVED|VIRTUAL_IP|MYIF|INTERFACE|STATE|PRIORITY|ROUTER_ID" | sort
echo "------------------------------"

echo "INFO: Checking for configuration file at $CONF_FILE..."
while [ ! -e "$CONF_FILE" ] && [ $CONF_TRIES -lt $MAX_CONF_TRIES ]; do
    sleep 1
    CONF_TRIES=$((CONF_TRIES + 1))
    if [ $((CONF_TRIES % 5)) -eq 0 ]; then
        echo "Still waiting for configuration file... ($CONF_TRIES/$MAX_CONF_TRIES)"
    fi
done

# 3. Check if a custom configuration file exists
if [ -e "$CONF_FILE" ]; then
    echo "INFO: Configuration detected at $CONF_FILE. Skipping auto-generation."
else
    # Generate a basic configuration using environment variables if no file is provided
    echo "INFO: No custom config found. Generating configuration from environment variables..."
    
    # Set default values if variables are not provided by Docker Compose/Environment
    STATE=${STATE:-MASTER}
    PRIORITY=${PRIORITY:-100}
    INTERFACE="${MYIF:-${INTERFACE:-eth0}}"
    ROUTER_ID=${ROUTER_ID:-51}
    VIRTUAL_IP=${VIRTUAL_IP} # Removed dangerous 192.168.1.1 default

    if [ -z "$VIRTUAL_IP" ]; then
        echo "ERROR: No VIRTUAL_IP provided and no config file found. Cannot proceed safely."
        exit 1
    fi

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
    echo "INFO: Basic configuration generated successfully for VIP $VIRTUAL_IP."
fi

# 4. Wait for network interface readiness
# Prioritize MYIF (common in this stack) over INTERFACE, default to eth0
WAIT_IF="${MYIF:-${INTERFACE:-eth0}}"

echo "INFO: Waiting for interface $WAIT_IF to be UP..."
MAX_TRIES=60 # Increased from 30 to 60 for slow reboots
TRIES=0
while ! ip link show "$WAIT_IF" 2>/dev/null | grep -q "UP,LOWER_UP" && [ $TRIES -lt $MAX_TRIES ]; do
    sleep 1
    TRIES=$((TRIES + 1))
    if [ $((TRIES % 10)) -eq 0 ]; then
        echo "Still waiting for $WAIT_IF ($TRIES/$MAX_TRIES)..."
        # Log error if interface doesn't even exist
        if ! ip link show "$WAIT_IF" >/dev/null 2>&1; then
            echo "  (Interface $WAIT_IF does not exist yet)"
        fi
    fi
done

# Check final state of the interface
if ! ip link show "$WAIT_IF" | grep -q "UP,LOWER_UP"; then
    echo "WARNING: Interface $WAIT_IF is not fully UP after $MAX_TRIES seconds."
    if ! ip link show "$WAIT_IF" >/dev/null 2>&1; then
        echo "ERROR: Interface $WAIT_IF does not exist. Keepalived will likely fail. Exiting."
        exit 1
    fi
fi

# 5. Diagnostic logging
echo "--- Diagnostic Information ---"
echo "Interface state:"
ip addr show "$WAIT_IF" || echo "Could not get interface address"
echo "Routing table:"
ip route show || echo "Could not get routing table"
echo "Config file header (first 5 lines):"
head -n 5 "$CONF_FILE"
echo "------------------------------"

# 6. Start Keepalived in foreground
echo "INFO: Launching Keepalived binary..."
exec /usr/sbin/keepalived -f "$CONF_FILE" --dont-fork --log-console --log-detail
