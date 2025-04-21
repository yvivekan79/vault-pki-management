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

## Documentation

For detailed documentation, see the `/docs` directory:

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [PKI Management](docs/pki-management.md)
- [SoftHSM Integration](docs/softhsm-integration.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

