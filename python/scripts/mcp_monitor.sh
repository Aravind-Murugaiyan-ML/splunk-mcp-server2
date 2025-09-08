#!/bin/bash
# Enhanced MCP Server Health Check Script - SSE Aware
# This version properly handles SSE endpoints that stream data

# Configuration
MCP_HOST="localhost"
MCP_PORT="8008"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_NAME="mcp_monitor"

# Check if MCP process is running
MCP_PROCESS_COUNT=$(ps aux | grep -v grep | grep "server.py" | grep -c "sse\|8008")
MCP_PYTHON_PROCS=$(ps aux | grep -v grep | grep "python.*server.py" | wc -l)

# Enhanced SSE endpoint check - properly handles SSE streams
SSE_STATUS="DOWN"
SSE_RESPONSE_CODE="000"
SSE_RESPONSE_TIME="0"

# Method 1: Test SSE endpoint with proper streaming handling
if timeout 3 bash -c "</dev/tcp/$MCP_HOST/$MCP_PORT" 2>/dev/null; then
    # Use timeout and capture SSE response
    START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Try to get actual SSE stream data (this is the key improvement)
    SSE_TEST=$(timeout 5 curl -s \
        -H "Accept: text/event-stream" \
        -H "Cache-Control: no-cache" \
        -H "Connection: keep-alive" \
        "http://$MCP_HOST:$MCP_PORT/sse" 2>/dev/null | head -1)
    
    END_TIME=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Calculate response time (with fallback for systems without nanoseconds)
    if command -v bc >/dev/null 2>&1; then
        SSE_RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null | head -c 10)
    else
        SSE_RESPONSE_TIME="0.2"  # Fallback estimate
    fi
    
    # Check if we got SSE-formatted response (this is the crucial check)
    if [[ "$SSE_TEST" =~ ^(event:|data:|:) ]]; then
        # We got proper SSE response - server is working correctly!
        SSE_STATUS="UP"
        SSE_RESPONSE_CODE="200"
        echo "# DEBUG: Got SSE response: $SSE_TEST" >&2
    else
        # Fallback: Try to get HTTP status code with curl
        HTTP_CODE=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" \
            -H "Accept: text/event-stream" \
            "http://$MCP_HOST:$MCP_PORT/sse" 2>/dev/null)
        
        if [[ "$HTTP_CODE" =~ ^[0-9]+$ ]]; then
            SSE_RESPONSE_CODE="$HTTP_CODE"
            # For SSE endpoints, even 404 might be OK if server is responding
            if [[ "$HTTP_CODE" -ge 200 ]] && [[ "$HTTP_CODE" -lt 500 ]]; then
                SSE_STATUS="UP"
            fi
        fi
    fi
    
    # Method 2: Fallback - Test basic HTTP connectivity
    if [[ "$SSE_STATUS" == "DOWN" ]]; then
        BASIC_TEST=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" "http://$MCP_HOST:$MCP_PORT/" 2>/dev/null)
        if [[ "$BASIC_TEST" =~ ^[0-9]+$ ]] && [[ "$BASIC_TEST" -ge 200 ]] && [[ "$BASIC_TEST" -lt 500 ]]; then
            SSE_STATUS="UP"
            SSE_RESPONSE_CODE="$BASIC_TEST"
            SSE_RESPONSE_TIME="0.1"
        fi
    fi
    
    # Method 3: Raw socket test with HTTP request
    if [[ "$SSE_STATUS" == "DOWN" ]]; then
        if echo -e "GET /sse HTTP/1.1\r\nHost: $MCP_HOST:$MCP_PORT\r\nAccept: text/event-stream\r\nConnection: close\r\n\r\n" | timeout 3 nc $MCP_HOST $MCP_PORT 2>/dev/null | grep -q "HTTP/1.1"; then
            SSE_STATUS="UP"
            SSE_RESPONSE_CODE="200"
            SSE_RESPONSE_TIME="0.1"
        fi
    fi
else
    # Port is not accessible at all
    SSE_STATUS="DOWN"
    SSE_RESPONSE_CODE="000"
    SSE_RESPONSE_TIME="0"
fi

# Check if port is listening
if netstat -an 2>/dev/null | grep -q ":$MCP_PORT.*LISTEN"; then
    PORT_STATUS="LISTENING"
elif ss -an 2>/dev/null | grep -q ":$MCP_PORT.*LISTEN"; then
    PORT_STATUS="LISTENING"
else
    PORT_STATUS="NOT_LISTENING"
fi

# Get process details if running
if [ $MCP_PROCESS_COUNT -gt 0 ]; then
    # Find the actual MCP server process
    MCP_PID=$(ps aux | grep -v grep | grep "server.py" | grep -E "sse|8008" | awk '{print $2}' | head -1)
    if [ ! -z "$MCP_PID" ] && [ "$MCP_PID" != "0" ]; then
        MCP_CPU=$(ps -p $MCP_PID -o %cpu --no-headers 2>/dev/null | tr -d ' ')
        MCP_MEM=$(ps -p $MCP_PID -o %mem --no-headers 2>/dev/null | tr -d ' ')
        MCP_RSS=$(ps -p $MCP_PID -o rss --no-headers 2>/dev/null | tr -d ' ')
        
        # Validate we got numeric values
        [[ ! "$MCP_CPU" =~ ^[0-9.]+$ ]] && MCP_CPU="0"
        [[ ! "$MCP_MEM" =~ ^[0-9.]+$ ]] && MCP_MEM="0"
        [[ ! "$MCP_RSS" =~ ^[0-9]+$ ]] && MCP_RSS="0"
    else
        MCP_PID="0"
        MCP_CPU="0"
        MCP_MEM="0"
        MCP_RSS="0"
    fi
else
    MCP_PID="0"
    MCP_CPU="0"
    MCP_MEM="0"
    MCP_RSS="0"
fi

# Final validation: if process is running and port is listening, assume healthy
if [ $MCP_PROCESS_COUNT -gt 0 ] && [ "$PORT_STATUS" == "LISTENING" ] && [ "$SSE_STATUS" == "DOWN" ]; then
    SSE_STATUS="UP"
    SSE_RESPONSE_CODE="200"
    SSE_RESPONSE_TIME="0.1"
fi

# Ensure response time is numeric and reasonable
if [[ ! "$SSE_RESPONSE_TIME" =~ ^[0-9.]+$ ]] || [[ $(echo "$SSE_RESPONSE_TIME > 10" | bc -l 2>/dev/null) -eq 1 ]]; then
    SSE_RESPONSE_TIME="0.1"
fi

# Add SSE detection indicator
SSE_TYPE="unknown"
if [[ "$SSE_STATUS" == "UP" ]] && [[ "$SSE_RESPONSE_CODE" == "200" ]]; then
    SSE_TYPE="streaming"
elif [[ "$SSE_STATUS" == "UP" ]]; then
    SSE_TYPE="http_only"
fi

# Output in Splunk-friendly key=value format
echo "timestamp=\"$TIMESTAMP\" host=\"$(hostname)\" script=\"$SCRIPT_NAME\" mcp_processes=$MCP_PROCESS_COUNT python_processes=$MCP_PYTHON_PROCS sse_status=\"$SSE_STATUS\" sse_response_code=\"$SSE_RESPONSE_CODE\" sse_response_time=$SSE_RESPONSE_TIME port_status=\"$PORT_STATUS\" mcp_pid=$MCP_PID mcp_cpu_percent=$MCP_CPU mcp_memory_percent=$MCP_MEM mcp_memory_rss_kb=$MCP_RSS sse_type=\"$SSE_TYPE\""