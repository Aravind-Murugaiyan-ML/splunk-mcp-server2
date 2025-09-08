#!/bin/bash
# File: /opt/splunk/bin/scripts/splunk_metrics.sh
# Purpose: Collect Splunk performance metrics

# Get timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to get Splunk internal metrics
get_splunk_metrics() {
    # Indexing rate (events per second) - get from _internal logs
    INDEXING_RATE=$(echo 'index=_internal source=*metrics.log* group=per_index_thruput | stats avg(eps) as avg_eps | eval indexing_rate=round(avg_eps,2) | fields indexing_rate' | /opt/splunk/bin/splunk search -maxout 1 -output csv | tail -1 | cut -d, -f1)
    
    # If splunk search fails, get approximate indexing rate from recent data
    if [ -z "$INDEXING_RATE" ] || [ "$INDEXING_RATE" = "indexing_rate" ]; then
        # Fallback: count recent events across all indexes
        RECENT_EVENTS=$(echo 'index=* earliest=-1m | stats count' | /opt/splunk/bin/splunk search -maxout 1 -output csv | tail -1)
        INDEXING_RATE=$(echo "$RECENT_EVENTS / 60" | bc -l 2>/dev/null | cut -d. -f1)
        [ -z "$INDEXING_RATE" ] && INDEXING_RATE=0
    fi
    
    # Search concurrency - get current running searches
    SEARCH_CONCURRENCY=$(echo 'index=_audit action=search | stats dc(search_id) as concurrent_searches | fields concurrent_searches' | /opt/splunk/bin/splunk search -maxout 1 -output csv | tail -1)
    [ -z "$SEARCH_CONCURRENCY" ] || [ "$SEARCH_CONCURRENCY" = "concurrent_searches" ] && SEARCH_CONCURRENCY=0
    
    # Disk usage - get Splunk home directory usage
    SPLUNK_HOME_USAGE=$(df /opt/splunk | tail -1 | awk '{print $5}' | sed 's/%//')
    DISK_USAGE=${SPLUNK_HOME_USAGE:-0}
    
    # Additional metrics
    TOTAL_INDEXES=$(echo 'index=* | stats dc(index) as total_indexes | fields total_indexes' | /opt/splunk/bin/splunk search -maxout 1 -output csv | tail -1)
    [ -z "$TOTAL_INDEXES" ] || [ "$TOTAL_INDEXES" = "total_indexes" ] && TOTAL_INDEXES=0
    
    # Memory usage
    MEMORY_USAGE=$(ps aux | grep splunkd | grep -v grep | awk '{sum+=$4} END {print sum}' | cut -d. -f1)
    [ -z "$MEMORY_USAGE" ] && MEMORY_USAGE=0
    
    # CPU usage of Splunk processes
    CPU_USAGE=$(ps aux | grep splunkd | grep -v grep | awk '{sum+=$3} END {print sum}' | cut -d. -f1)
    [ -z "$CPU_USAGE" ] && CPU_USAGE=0
    
    echo "$INDEXING_RATE" "$SEARCH_CONCURRENCY" "$DISK_USAGE" "$TOTAL_INDEXES" "$MEMORY_USAGE" "$CPU_USAGE"
}

# Get the metrics
METRICS_DATA=$(get_splunk_metrics)
INDEXING_RATE=$(echo "$METRICS_DATA" | awk '{print $1}')
SEARCH_CONCURRENCY=$(echo "$METRICS_DATA" | awk '{print $2}')
DISK_USAGE=$(echo "$METRICS_DATA" | awk '{print $3}')
TOTAL_INDEXES=$(echo "$METRICS_DATA" | awk '{print $4}')
MEMORY_USAGE=$(echo "$METRICS_DATA" | awk '{print $5}')
CPU_USAGE=$(echo "$METRICS_DATA" | awk '{print $6}')

# Output in the exact format expected by the dashboard (key=value pairs)
echo "${TIMESTAMP} indexing_rate=${INDEXING_RATE} search_concurrency=${SEARCH_CONCURRENCY} disk_usage=${DISK_USAGE} total_indexes=${TOTAL_INDEXES} memory_usage=${MEMORY_USAGE} cpu_usage=${CPU_USAGE} event_type=\"splunk_metrics\""
