#!/bin/sh
set -e

# Path to the final configuration file
CONF_FILE="/etc/keepalived/keepalived.conf"

echo "--- Keepalived Startup Process ---"

# Check if a custom configuration file was mounted via volume
if [ -f "$CONF_FILE" ] && [ ! -L "$CONF_FILE" ]; then
    echo "INFO: Custom configuration found at $CONF_FILE. Skipping auto-generation."
else
    # Generate a basic configuration using environment variables if no file is provided
    echo "INFO: No custom config detected. Generating configuration from environment variables..."
    
    # Set default values if variables are not provided by Docker Compose/Environment
    STATE=${STATE:-MASTER}
    PRIORITY=${PRIORITY:-100}
    INTERFACE=${INTERFACE:-eth0}
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

# Start Keepalived in foreground
# --dont-fork: Keeps the process in foreground for Docker logs
# --log-console: Directs logs to stdout/stderr
# --log-detail: Provides verbose logging for easier debugging
echo "INFO: Launching Keepalived binary..."
exec /usr/sbin/keepalived -f "$CONF_FILE" --dont-fork --log-console --log-detail
