# Vault PKI Management API Client Examples

This directory contains client examples for interacting with the Vault PKI Management API.

## Python Client

The `python_client.py` script provides a comprehensive Python client for interacting with the API. It demonstrates how to list certificates, issue new certificates, revoke certificates, and manage Vault servers.

### Installation

Requirements:
- Python 3.6 or later
- `requests` library

Install the dependencies:

```bash
pip install requests
```

### Usage

The script can be used in two ways:
1. As a command-line tool for performing specific operations
2. As a library that can be imported into other Python code

#### Command-Line Usage

The script supports various commands:

```bash
# Check API health
python python_client.py health

# List all certificates
python python_client.py list-certificates

# Get details for a specific certificate
python python_client.py get-certificate 1

# Issue a new certificate
python python_client.py issue-certificate example.com --ttl 720h --role server \
  --alt-names www.example.com,api.example.com --ip-sans 192.168.1.100

# Revoke a certificate
python python_client.py revoke-certificate 5

# List all Vault servers
python python_client.py list-servers

# Get details for a specific Vault server
python python_client.py get-server 1

# Unseal a Vault server
python python_client.py unseal-server 1

# Run a demonstration of various API operations
python python_client.py demo
```

You can specify the API base URL and, if required, an API key:

```bash
python python_client.py --url http://your-server:5000/api/v1 --api-key your-api-key list-certificates
```

#### Library Usage

You can also import the client into your own Python code:

```python
from python_client import VaultPKIClient

# Initialize the client
client = VaultPKIClient("http://localhost:5000/api/v1")

# List certificates
certificates = client.get_certificates()
print(certificates)

# Issue a new certificate
new_cert = client.issue_certificate(
    common_name="example.com",
    ttl="8760h",
    role="server",
    alt_names="www.example.com,api.example.com"
)
print(new_cert)

# Revoke a certificate
revoke_result = client.revoke_certificate(5)
print(revoke_result)
```

### Example Applications

#### Automatic Certificate Renewal

This example shows how to automatically renew certificates that are nearing expiration:

```python
import time
from datetime import datetime, timedelta
from python_client import VaultPKIClient

def renew_expiring_certificates(client, days_before_expiry=30):
    """Renew certificates that are expiring soon"""
    certificates = client.get_certificates()["certificates"]
    
    now = datetime.now()
    renewal_threshold = now + timedelta(days=days_before_expiry)
    
    for cert in certificates:
        expiry_date = datetime.fromisoformat(cert["valid_until"])
        
        # Check if certificate is expiring soon
        if expiry_date < renewal_threshold and cert["status"] == "valid":
            print(f"Certificate {cert['name']} is expiring soon. Renewing...")
            
            # Issue a new certificate with the same details
            new_cert = client.issue_certificate(
                common_name=cert["common_name"],
                ttl="8760h",  # 1 year
                role="server"
            )
            
            print(f"Renewed certificate: {new_cert['certificate_id']}")

# Usage
client = VaultPKIClient("http://localhost:5000/api/v1")
renew_expiring_certificates(client)
```

#### Certificate Deployment

This example demonstrates how to fetch and deploy certificates to an application:

```python
import os
from python_client import VaultPKIClient

def deploy_certificate(client, cert_id, output_dir):
    """Fetch a certificate and save it to disk for use by an application"""
    cert_details = client.get_certificate(cert_id)
    
    # In a real implementation, the API would return the actual certificate data
    # For this demo, we'll create dummy files
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Write certificate info to a text file
    with open(os.path.join(output_dir, "certificate_info.txt"), "w") as f:
        f.write(f"Certificate Name: {cert_details['name']}\n")
        f.write(f"Common Name: {cert_details['common_name']}\n")
        f.write(f"Issuer: {cert_details['issuer']}\n")
        f.write(f"Valid From: {cert_details['valid_from']}\n")
        f.write(f"Valid Until: {cert_details['valid_until']}\n")
        f.write(f"Status: {cert_details['status']}\n")
    
    print(f"Certificate info saved to {output_dir}/certificate_info.txt")
    
    # In a real implementation, you would save the actual certificate files:
    # - certificate.pem
    # - private_key.pem
    # - ca_chain.pem

# Usage
client = VaultPKIClient("http://localhost:5000/api/v1")
deploy_certificate(client, 1, "./certs")
```

## Other Language Examples

Examples for other programming languages could be added here in the future, such as:
- Go
- Java
- JavaScript/Node.js
- Ruby
- PowerShell