#!/bin/bash
# Network Statistics Collection Script for Splunk

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

TOTAL_RX_BYTES=0
TOTAL_TX_BYTES=0
INTERFACES=""

while IFS= read -r line; do
    echo "$line" | grep -q ":" || continue
    INTERFACE=$(echo "$line" | cut -d: -f1 | xargs)
    [ "$INTERFACE" = "lo" ] && continue
    
    STATS=$(echo "$line" | cut -d: -f2)
    RX_BYTES=$(echo "$STATS" | awk '{print $1}')
    TX_BYTES=$(echo "$STATS" | awk '{print $9}')
    
    TOTAL_RX_BYTES=$((TOTAL_RX_BYTES + RX_BYTES))
    TOTAL_TX_BYTES=$((TOTAL_TX_BYTES + TX_BYTES))
    INTERFACES="${INTERFACES}${INTERFACE},"
done < /proc/net/dev

KILOBYTES_RECEIVED=$((TOTAL_RX_BYTES / 1024))
KILOBYTES_TRANSMITTED=$((TOTAL_TX_BYTES / 1024))
INTERFACES=${INTERFACES%,}

echo "${TIMESTAMP} kilobytes_received=${KILOBYTES_RECEIVED} kilobytes_transmitted=${KILOBYTES_TRANSMITTED} total_rx_bytes=${TOTAL_RX_BYTES} total_tx_bytes=${TOTAL_TX_BYTES} interfaces=\"${INTERFACES}\" event_type=\"network_stats\""
