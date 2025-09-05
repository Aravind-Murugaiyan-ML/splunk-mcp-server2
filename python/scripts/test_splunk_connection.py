#!/usr/bin/env python3
import os
import requests
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def test_splunk_connection():
    # Read from .env file manually or use environment variables
    host = os.getenv('SPLUNK_HOST', 'localhost')
    port = os.getenv('SPLUNK_PORT', '8089')
    username = os.getenv('SPLUNK_USERNAME', 'admin')
    password = os.getenv('SPLUNK_PASSWORD', 'mynewpassword123')
    scheme = 'https'  # Default scheme
    verify_ssl = os.getenv('VERIFY_SSL', 'false').lower() == 'true'
    
    print(f"Testing connection to: {scheme}://{host}:{port}")
    print(f"Username: {username}")
    print(f"SSL Verification: {verify_ssl}")
    print("-" * 50)
    
    # Test 1: Basic connectivity
    try:
        url = f"{scheme}://{host}:{port}/services/apps/local"
        response = requests.get(
            url,
            auth=(username, password),
            verify=verify_ssl,
            timeout=10
        )
        
        if response.status_code == 200:
            print("✅ Basic connectivity: SUCCESS")
            print(f"   Status Code: {response.status_code}")
        else:
            print(f"❌ Basic connectivity: FAILED")
            print(f"   Status Code: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
            
    except Exception as e:
        print(f"❌ Connection Error: {str(e)}")
        return False
    
    # Test 2: Search capability
    try:
        search_url = f"{scheme}://{host}:{port}/services/search/jobs"
        search_data = {
            'search': '| stats count',
            'output_mode': 'json'
        }
        
        search_response = requests.post(
            search_url,
            auth=(username, password),
            data=search_data,
            verify=verify_ssl,
            timeout=15
        )
        
        if search_response.status_code in [200, 201]:
            print("✅ Search capability: SUCCESS")
        else:
            print(f"❌ Search capability: FAILED")
            print(f"   Status Code: {search_response.status_code}")
            
    except Exception as e:
        print(f"❌ Search Test Error: {str(e)}")
    
    # Test 3: List indexes
    try:
        indexes_url = f"{scheme}://{host}:{port}/services/data/indexes"
        indexes_response = requests.get(
            indexes_url,
            auth=(username, password),
            verify=verify_ssl,
            timeout=10
        )
        
        if indexes_response.status_code == 200:
            print("✅ Index access: SUCCESS")
        else:
            print(f"❌ Index access: FAILED")
            
    except Exception as e:
        print(f"❌ Index Test Error: {str(e)}")
    
    print("-" * 50)
    print("Connection test completed!")
    return True

if __name__ == "__main__":
    test_splunk_connection()