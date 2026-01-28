#!/bin/bash
set -e

CONF_FILE="/etc/keepalived/keepalived.conf"
TEMPLATE_FILE="/etc/keepalived/keepalived.conf.template"

echo "--- Keepalived Starting ---"

# Scenario A: Se hai montato un file da fuori, usiamo quello
if [ -f "$CONF_FILE" ] && [ ! -L "$CONF_FILE" ]; then
    echo "Custom configuration detected via volume. Using it."
else
    # Scenario B: Generiamo la configurazione dalle variabili
    echo "No custom config found. Generating from environment variables..."
    
    # Valori di default se mancano le variabili
    STATE=${STATE:-MASTER}
    PRIORITY=${PRIORITY:-100}
    INTERFACE=${INTERFACE:-eth0}
    ROUTER_ID=${ROUTER_ID:-51}
    VIRTUAL_IP=${VIRTUAL_IP:-192.168.1.1}

    cat <<EOF > $CONF_FILE
vrrp_instance VI_1 {
    state $STATE
    interface $INTERFACE
    virtual_router_id $ROUTER_ID
    priority $PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1234
    }
    virtual_ipaddress {
        $VIRTUAL_IP
    }
}
EOF
    echo "Configuration generated at $CONF_FILE"
fi

# Lancio del processo (sempre in foreground per i log di Docker)
exec /usr/sbin/keepalived -f "$CONF_FILE" --dont-fork --log-console --log-detail
