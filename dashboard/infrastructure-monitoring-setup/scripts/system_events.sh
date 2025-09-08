#!/bin/bash
# File: /opt/splunk/bin/scripts/system_events.sh
# Purpose: Generate sample system events for dashboard testing

# Get timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOST=$(hostname)

# Array of sample system events
EVENTS=(
    "INFO: System startup completed successfully"
    "WARNING: High memory usage detected - 85% utilized"
    "ERROR: Failed to connect to database server"
    "INFO: User login successful for admin"
    "WARNING: Disk space running low on /var partition"
    "ERROR: Network timeout occurred during backup"
    "INFO: Service restart completed"
    "WARNING: CPU temperature threshold exceeded"
    "ERROR: Authentication failed for user guest"
    "INFO: System update installed successfully"
    "WARNING: SSL certificate expires in 30 days"
    "ERROR: Failed to start apache service"
    "INFO: Backup completed successfully"
    "WARNING: Security scan detected vulnerabilities"
    "ERROR: Database connection pool exhausted"
)

# Select a random event
RANDOM_INDEX=$((RANDOM % ${#EVENTS[@]}))
EVENT="${EVENTS[$RANDOM_INDEX]}"

# Determine log level
if [[ "$EVENT" == *"ERROR"* ]]; then
    LEVEL="ERROR"
elif [[ "$EVENT" == *"WARNING"* ]]; then
    LEVEL="WARNING"
else
    LEVEL="INFO"
fi

# Generate realistic system log format
echo "${TIMESTAMP} ${HOST} system-monitor[$$]: ${LEVEL}: ${EVENT} event_type=\"system_event\""

# Occasionally log to actual syslog for variety
if [ $((RANDOM % 3)) -eq 0 ]; then
    logger -t "system-monitor" "${LEVEL}: ${EVENT}"
fi
