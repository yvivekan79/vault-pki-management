#!/bin/bash
# Demo script to test the Vault PKI Management API

# Base URL of the API
API_URL="http://localhost:5000/api/v1"

# Function to make HTTP requests
function api_request() {
    method=$1
    endpoint=$2
    data=$3
    
    if [ -z "$data" ]; then
        curl -s -X "$method" "$API_URL/$endpoint" | jq .
    else
        curl -s -X "$method" -H "Content-Type: application/json" -d "$data" "$API_URL/$endpoint" | jq .
    fi
}

echo "=== Testing Vault PKI Management API ==="

echo -e "\n--- Health Check ---"
api_request "GET" "health"

echo -e "\n--- List All Certificates ---"
api_request "GET" "certificates"

echo -e "\n--- Get Specific Certificate (ID: 1) ---"
api_request "GET" "certificates/1"

echo -e "\n--- Issue New Certificate ---"
issue_data='{"common_name":"demo-api.example.com","ttl":"720h","role":"server","alt_names":"www.demo-api.example.com","ip_sans":"192.168.1.100"}'
issue_response=$(api_request "POST" "certificates/issue" "$issue_data")
echo "$issue_response"

# Extract the certificate ID from the response
cert_id=$(echo "$issue_response" | jq '.certificate_id')

echo -e "\n--- Get Newly Issued Certificate (ID: $cert_id) ---"
api_request "GET" "certificates/$cert_id"

echo -e "\n--- Revoke Certificate (ID: $cert_id) ---"
api_request "POST" "certificates/$cert_id/revoke"

echo -e "\n--- List All Vault Servers ---"
api_request "GET" "servers"

echo -e "\n--- Get Specific Vault Server (ID: 1) ---"
api_request "GET" "servers/1"

echo -e "\n=== API Testing Complete ==="