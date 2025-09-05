#!/usr/bin/env python3
import asyncio
import json
import time
from datetime import datetime

async def run_comprehensive_tests():
    """Run comprehensive tests for both STDIO and SSE modes"""
    
    print("=== Splunk MCP Server Comprehensive Test Suite ===")
    print(f"Test started at: {datetime.now()}")
    print("Execute from vSphere instance for local tests")
    print("Execute from client machine for remote tests")
    print("-" * 60)
    
    # Test cases
    test_cases = [
        {
            "name": "Basic Configuration",
            "query": "get_config",
            "params": {}
        },
        {
            "name": "List Indexes",
            "query": "get_indexes", 
            "params": {}
        },
        {
            "name": "Simple Search",
            "query": "search_oneshot",
            "params": {
                "search": "| stats count",
                "output_format": "json"
            }
        },
        {
            "name": "Internal Logs Search",
            "query": "search_oneshot",
            "params": {
                "search": "index=_internal | head 5",
                "output_format": "json"
            }
        },
        {
            "name": "SPL Validation - Safe Query",
            "query": "validate_spl",
            "params": {
                "search": "index=_internal | stats count by sourcetype"
            }
        },
        {
            "name": "SPL Validation - Risky Query",
            "query": "validate_spl",
            "params": {
                "search": "| delete"
            }
        }
    ]
    
    print("Test cases to execute:")
    for i, test in enumerate(test_cases, 1):
        print(f"  {i}. {test['name']}")
    
    print("\n" + "="*60)
    print("Execute these tests manually with claude-code:")
    print("="*60)
    
    for i, test in enumerate(test_cases, 1):
        print(f"\n--- Test {i}: {test['name']} ---")
        if test['params']:
            params_str = ', '.join([f"{k}='{v}'" for k, v in test['params'].items()])
            print(f"claude \"Use the Splunk MCP to {test['query']} with parameters: {params_str}\"")
        else:
            print(f"claude \"Use the Splunk MCP to {test['query']}\"")

if __name__ == "__main__":
    asyncio.run(run_comprehensive_tests())