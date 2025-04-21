# Vault PKI Infrastructure with SoftHSM2 Integration

This repository contains a production-ready deployment package for a highly available HashiCorp Vault PKI infrastructure with SoftHSM2 integration on Kubernetes. It includes a web-based management console for easy administration of the PKI infrastructure.

## Features

- Highly available HashiCorp Vault PKI CA deployment
- Integrated Raft storage for high availability
- PKCS#11 integration with SoftHSM2
- Auto-unsealing capability
- Complete PKI lifecycle management
- RBAC integration for access control
- Comprehensive deployment automation
- Web-based management console
- Certificate issuance, revocation, and lifecycle management
- Server status monitoring and operations

## Components

- **Vault**: HashiCorp's secret management tool used as a PKI Certificate Authority
- **SoftHSM2**: Software implementation of a Hardware Security Module
- **Kubernetes**: Container orchestration platform for deployment
- **Helm**: Package manager for Kubernetes applications
- **cert-manager**: Certificate management for Kubernetes
- **Flask**: Web framework for the management console
- **SQLAlchemy**: ORM for database operations in the management console

## Repository Structure

- `/config`: Configuration files for SoftHSM2 and Vault
- `/docs`: Comprehensive documentation including architecture, deployment guides, and troubleshooting
- `/helm-charts`: Helm charts for deploying the infrastructure on Kubernetes
- `/scripts`: Automation scripts for initialization, PKI setup, and testing
- `/templates`: HTML templates for the management console UI
- `main.py`: Flask application for the management console

## Management Console

The management console provides a web-based interface for:

1. **Dashboard**: Overview of Vault server status and certificate health
2. **Certificate Management**: Issue, revoke, and monitor certificates
3. **Server Management**: Monitor Vault server status, seal/unseal, and perform maintenance operations
4. **API Documentation**: Reference for the RESTful API endpoints

## Getting Started

### Deploying the Infrastructure

1. Clone this repository
2. Configure the values in `helm-charts/vault-pki/values.yaml`
3. Deploy using Helm:
   ```
   helm install vault-pki ./helm-charts/vault-pki \
     --namespace vault \
     --create-namespace \
     --values ./helm-charts/vault-pki/values.yaml
   ```
4. Initialize Vault using the provided script:
   ```
   ./scripts/init-vault.sh
   ```
5. Configure the PKI engine:
   ```
   ./scripts/configure-pki.sh
   ```

### Running the Management Console

1. Install the required Python dependencies:
   ```
   pip install -r requirements.txt
   ```
2. Run the Flask application:
   ```
   python main.py
   ```
   Or in production:
   ```
   gunicorn --bind 0.0.0.0:5000 main:app
   ```
3. Access the management console at `http://localhost:5000`

## Script Reference Guide

The `scripts` directory contains several important utilities to manage and operate your Vault PKI Infrastructure. Below is a detailed guide on each script's purpose, usage, and parameters.

### `init-vault.sh`

**Purpose:** Initializes a Vault server cluster, generating the initial root tokens and unseal keys.

**Usage:**
```bash
./scripts/init-vault.sh [OPTIONS]
```

**Options:**
- `-n, --namespace <namespace>`: Kubernetes namespace where Vault is deployed (default: vault)
- `-p, --pod <pod>`: Specific Vault pod to initialize (default: vault-pki-0)
- `-s, --shares <num>`: Number of key shares to split the unseal key into (default: 5)
- `-t, --threshold <num>`: Number of key shares required to reconstruct the master key (default: 3)
- `-o, --output <file>`: Output file to save the initialization keys and tokens (default: ./vault-init.json)
- `-h, --help`: Display help information

**Example:**
```bash
./scripts/init-vault.sh --namespace vault-prod --shares 7 --threshold 4
```

**Output:** This script saves the unseal keys and root token to the specified file and outputs them to the console. IMPORTANT: Keep this information secure!

### `configure-pki.sh`

**Purpose:** Configures Vault's PKI secrets engine, creates roles, and sets up certificate issuance policies.

**Usage:**
```bash
./scripts/configure-pki.sh [OPTIONS]
```

**Options:**
- `-n, --namespace <namespace>`: Kubernetes namespace where Vault is deployed (default: vault)
- `-p, --pod <pod>`: Specific Vault pod to configure (default: vault-pki-0)
- `-t, --token <token>`: Root token for Vault authentication
- `-d, --domain <domain>`: Base domain for the PKI (default: example.com)
- `-r, --root-ttl <ttl>`: TTL for the root certificate (default: 87600h)
- `-i, --intermediate-ttl <ttl>`: TTL for the intermediate certificate (default: 43800h)
- `-c, --config <file>`: Configuration file with PKI settings (default: ./config/pki-config.json)
- `-h, --help`: Display help information

**Example:**
```bash
./scripts/configure-pki.sh --token s.abcdefghijklmnopqrstuvwxyz --domain company.local
```

**Output:** Creates a PKI infrastructure with root and intermediate CAs, roles for issuing certificates, and appropriate policies.

### `setup-softhsm.sh`

**Purpose:** Initializes and configures SoftHSM for use with Vault, creating token slots and setting PINs.

**Usage:**
```bash
./scripts/setup-softhsm.sh [OPTIONS]
```

**Options:**
- `-c, --conf <file>`: Path to softhsm2.conf (default: ./config/softhsm2.conf)
- `-s, --slot <num>`: Slot number to initialize (default: 0)
- `-l, --label <label>`: Label for the token (default: vault-pki-token)
- `-p, --pin <pin>`: PIN for the token (default: auto-generated)
- `-h, --help`: Display help information

**Example:**
```bash
./scripts/setup-softhsm.sh --label production-hsm-token
```

**Output:** Initializes SoftHSM with the specified configuration and displays the token information needed for Vault configuration.

### `test-vault-ha.sh`

**Purpose:** Tests high availability and failover capabilities of the Vault cluster.

**Usage:**
```bash
./scripts/test-vault-ha.sh [OPTIONS]
```

**Options:**
- `-n, --namespace <namespace>`: Kubernetes namespace where Vault is deployed (default: vault)
- `-c, --count <num>`: Number of failover tests to perform (default: 5)
- `-i, --interval <seconds>`: Seconds between tests (default: 10)
- `-h, --help`: Display help information

**Example:**
```bash
./scripts/test-vault-ha.sh --count 10 --interval 5
```

**Output:** Performs a series of tests to validate Vault's high availability setup, including leader election and failover.

## Client Libraries and Examples

### Python Client

The repository includes a Python client for interacting with the Vault PKI Management API. This client simplifies the process of requesting, retrieving, and revoking certificates programmatically.

**Location:** `client_examples/python_client.py`

**Usage:**
```python
from python_client import VaultPKIClient

# Initialize the client
client = VaultPKIClient(
    base_url="http://localhost:5000/api/v1",
    api_key="your-api-key"  # If API key authentication is enabled
)

# Health check
health = client.check_health()
print(f"API health: {health}")

# List all certificates
certificates = client.get_certificates()
print(f"Found {len(certificates)} certificates")

# Issue a new certificate
new_cert = client.issue_certificate(
    common_name="app1.example.com",
    ttl="720h",
    alt_names="www.app1.example.com,api.app1.example.com",
    key_type="rsa",
    key_bits=2048,
    name="app1-certificate"
)
print(f"Issued certificate with ID: {new_cert['id']}")

# Get certificate details
cert_details = client.get_certificate(new_cert['id'])
print(f"Certificate valid until: {cert_details['valid_until']}")

# Revoke a certificate
client.revoke_certificate(new_cert['id'])
print(f"Certificate {new_cert['id']} has been revoked")
```

**Advanced Features:**
- Server Management: `get_servers()`, `get_server(server_id)`, `unseal_server(server_id)`
- Error Handling: The client includes robust error handling for API responses

### Shell Script Examples

The `client_examples/demo.sh` script demonstrates how to use curl to interact with the API directly:

**Usage:**
```bash
./client_examples/demo.sh [API_BASE_URL] [API_KEY]
```

**Example:**
```bash
./client_examples/demo.sh http://localhost:5000/api/v1 your-api-key
```

The script demonstrates:
1. Health check requests
2. Certificate listing and querying
3. Certificate issuance with various parameters
4. Certificate revocation
5. Server status monitoring

This is particularly useful for integrating with CI/CD pipelines or automation tools that need to request or validate certificates.

## Documentation

For detailed documentation, see the `/docs` directory:

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [PKI Management](docs/pki-management.md)
- [SoftHSM Integration](docs/softhsm-integration.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

