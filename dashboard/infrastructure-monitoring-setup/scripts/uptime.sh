#!/bin/bash
# Splunk Uptime Collection Script

# Get uptime information
UPTIME_SECONDS=$(awk '{print int($1)}' /proc/uptime)
LOAD_1MIN=$(awk '{print $1}' /proc/loadavg)
LOAD_5MIN=$(awk '{print $2}' /proc/loadavg)
LOAD_15MIN=$(awk '{print $3}' /proc/loadavg)

# Calculate human readable uptime
DAYS=$((UPTIME_SECONDS / 86400))
HOURS=$(((UPTIME_SECONDS % 86400) / 3600))
MINUTES=$(((UPTIME_SECONDS % 3600) / 60))

# Get current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Output structured data for Splunk
echo "${TIMESTAMP} uptime_seconds=${UPTIME_SECONDS} uptime_days=${DAYS} uptime_hours=${HOURS} uptime_minutes=${MINUTES} load_1min=${LOAD_1MIN} load_5min=${LOAD_5MIN} load_15min=${LOAD_15MIN} status=\"System Running\" uptime_display=\"${DAYS}d ${HOURS}h ${MINUTES}m\" event_type=\"uptime\""
