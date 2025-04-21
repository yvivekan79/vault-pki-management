#!/usr/bin/env python3
"""
Vault PKI Management API Client Example

This script demonstrates how to interact with the Vault PKI Management API
to perform various operations like listing certificates, issuing new certificates,
and revoking certificates.
"""

import argparse
import json
import requests
import sys
from datetime import datetime
import time

class VaultPKIClient:
    """Client for interacting with the Vault PKI Management API"""
    
    def __init__(self, base_url, api_key=None):
        """
        Initialize the client with the base URL and API key.
        
        Args:
            base_url (str): Base URL of the API (e.g., "http://localhost:5000/api/v1")
            api_key (str, optional): API key for authentication (if required)
        """
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.session = requests.Session()
        
        # Set up API key authentication if provided
        if api_key:
            self.session.headers.update({'Authorization': f'Bearer {api_key}'})
    
    def _get_url(self, endpoint):
        """Construct full URL for the given endpoint"""
        return f"{self.base_url}/{endpoint.lstrip('/')}"
    
    def _handle_response(self, response):
        """Handle API response, raising exceptions for errors"""
        try:
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as err:
            error_msg = f"HTTP Error: {err}"
            try:
                error_data = response.json()
                if 'error' in error_data:
                    error_msg = f"API Error: {error_data['error']}"
            except ValueError:
                pass
            print(f"Error: {error_msg}", file=sys.stderr)
            raise
    
    def get_certificates(self):
        """Get a list of all certificates"""
        response = self.session.get(self._get_url('/certificates'))
        return self._handle_response(response)
    
    def get_certificate(self, certificate_id):
        """Get details for a specific certificate"""
        response = self.session.get(self._get_url(f'/certificates/{certificate_id}'))
        return self._handle_response(response)
    
    def issue_certificate(self, common_name, ttl="8760h", role="server", 
                          alt_names=None, ip_sans=None, key_type="rsa", 
                          key_bits=2048, name=None):
        """
        Issue a new certificate
        
        Args:
            common_name (str): Common name for the certificate
            ttl (str): Time to live in format like "8760h" for 1 year
            role (str): Role to use for issuing the certificate
            alt_names (str, optional): Comma-separated list of subject alternative names
            ip_sans (str, optional): Comma-separated list of IP addresses to include as SANs
            key_type (str, optional): Key type (default: "rsa")
            key_bits (int, optional): Key size in bits (default: 2048)
            name (str, optional): Custom name for the certificate
            
        Returns:
            dict: The API response containing the issued certificate details
        """
        data = {
            "common_name": common_name,
            "ttl": ttl,
            "role": role,
            "key_type": key_type,
            "key_bits": key_bits
        }
        
        if alt_names:
            data["alt_names"] = alt_names
        if ip_sans:
            data["ip_sans"] = ip_sans
        if name:
            data["name"] = name
        
        response = self.session.post(
            self._get_url('/certificates/issue'),
            json=data
        )
        return self._handle_response(response)
    
    def revoke_certificate(self, certificate_id):
        """Revoke a certificate"""
        response = self.session.post(
            self._get_url(f'/certificates/{certificate_id}/revoke')
        )
        return self._handle_response(response)
    
    def get_servers(self):
        """Get a list of all Vault servers"""
        response = self.session.get(self._get_url('/servers'))
        return self._handle_response(response)
    
    def get_server(self, server_id):
        """Get details for a specific Vault server"""
        response = self.session.get(self._get_url(f'/servers/{server_id}'))
        return self._handle_response(response)
    
    def unseal_server(self, server_id):
        """Unseal a Vault server"""
        response = self.session.post(
            self._get_url(f'/servers/{server_id}/unseal')
        )
        return self._handle_response(response)
    
    def check_health(self):
        """Check the health of the API service"""
        response = self.session.get(self._get_url('/health'))
        return self._handle_response(response)


def print_json(data):
    """Print JSON data in a readable format"""
    print(json.dumps(data, indent=2))


def main():
    parser = argparse.ArgumentParser(description='Vault PKI Management API Client')
    parser.add_argument('--url', default='http://localhost:5000/api/v1',
                        help='Base URL of the API (default: http://localhost:5000/api/v1)')
    parser.add_argument('--api-key', help='API key for authentication (if required)')
    
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # List certificates command
    subparsers.add_parser('list-certificates', help='List all certificates')
    
    # Get certificate command
    get_cert_parser = subparsers.add_parser('get-certificate', help='Get certificate details')
    get_cert_parser.add_argument('certificate_id', type=int, help='Certificate ID')
    
    # Issue certificate command
    issue_cert_parser = subparsers.add_parser('issue-certificate', help='Issue a new certificate')
    issue_cert_parser.add_argument('common_name', help='Common name for the certificate')
    issue_cert_parser.add_argument('--ttl', default='8760h', help='Time to live (default: 8760h)')
    issue_cert_parser.add_argument('--role', default='server', help='Role to use (default: server)')
    issue_cert_parser.add_argument('--alt-names', help='Comma-separated list of subject alternative names')
    issue_cert_parser.add_argument('--ip-sans', help='Comma-separated list of IP addresses to include as SANs')
    issue_cert_parser.add_argument('--key-type', default='rsa', help='Key type (default: rsa)')
    issue_cert_parser.add_argument('--key-bits', type=int, default=2048, help='Key size in bits (default: 2048)')
    issue_cert_parser.add_argument('--name', help='Custom name for the certificate')
    
    # Revoke certificate command
    revoke_cert_parser = subparsers.add_parser('revoke-certificate', help='Revoke a certificate')
    revoke_cert_parser.add_argument('certificate_id', type=int, help='Certificate ID')
    
    # List servers command
    subparsers.add_parser('list-servers', help='List all Vault servers')
    
    # Get server command
    get_server_parser = subparsers.add_parser('get-server', help='Get server details')
    get_server_parser.add_argument('server_id', type=int, help='Server ID')
    
    # Unseal server command
    unseal_server_parser = subparsers.add_parser('unseal-server', help='Unseal a Vault server')
    unseal_server_parser.add_argument('server_id', type=int, help='Server ID')
    
    # Health check command
    subparsers.add_parser('health', help='Check the health of the API service')
    
    # Demo command (runs through a series of operations)
    subparsers.add_parser('demo', help='Run a demonstration of various API operations')
    
    args = parser.parse_args()
    
    # Initialize the client
    client = VaultPKIClient(args.url, args.api_key)
    
    # Execute the appropriate command
    if args.command == 'list-certificates':
        print_json(client.get_certificates())
    
    elif args.command == 'get-certificate':
        print_json(client.get_certificate(args.certificate_id))
    
    elif args.command == 'issue-certificate':
        print_json(client.issue_certificate(
            args.common_name,
            ttl=args.ttl,
            role=args.role,
            alt_names=args.alt_names,
            ip_sans=args.ip_sans,
            key_type=args.key_type,
            key_bits=args.key_bits,
            name=args.name
        ))
    
    elif args.command == 'revoke-certificate':
        print_json(client.revoke_certificate(args.certificate_id))
    
    elif args.command == 'list-servers':
        print_json(client.get_servers())
    
    elif args.command == 'get-server':
        print_json(client.get_server(args.server_id))
    
    elif args.command == 'unseal-server':
        print_json(client.unseal_server(args.server_id))
    
    elif args.command == 'health':
        print_json(client.check_health())
    
    elif args.command == 'demo':
        print("=== Running API Demo ===")
        
        print("\n--- Checking API Health ---")
        health = client.check_health()
        print_json(health)
        
        print("\n--- Listing Vault Servers ---")
        servers = client.get_servers()
        print_json(servers)
        
        print("\n--- Listing Existing Certificates ---")
        certs = client.get_certificates()
        print_json(certs)
        
        print("\n--- Issuing a New Certificate ---")
        new_cert = client.issue_certificate(
            common_name="demo.example.com",
            ttl="720h",
            role="server",
            alt_names="www.demo.example.com,api.demo.example.com",
            ip_sans="192.168.1.100,10.0.0.50"
        )
        print_json(new_cert)
        
        cert_id = new_cert['certificate_id']
        
        print("\n--- Retrieving Certificate Details ---")
        cert_details = client.get_certificate(cert_id)
        print_json(cert_details)
        
        print("\n--- Revoking the Certificate ---")
        time.sleep(1)  # Small delay to see the sequence of events clearly
        revoke_result = client.revoke_certificate(cert_id)
        print_json(revoke_result)
        
        print("\n--- Verifying Certificate Status After Revocation ---")
        time.sleep(1)  # Small delay
        cert_after_revoke = client.get_certificate(cert_id)
        print_json(cert_after_revoke)
        
        print("\n=== Demo Completed ===")
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()