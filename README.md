# Vault PKI Infrastructure with SoftHSM2 Integration

This repository contains a production-ready deployment package for a highly available HashiCorp Vault PKI infrastructure with SoftHSM2 integration on Kubernetes.

## Features

- Highly available HashiCorp Vault PKI CA deployment
- Integrated Raft storage for high availability
- PKCS#11 integration with SoftHSM2
- Auto-unsealing capability
- Complete PKI lifecycle management
- RBAC integration for access control
- Comprehensive deployment automation

## Components

- **Vault**: HashiCorp's secret management tool used as a PKI Certificate Authority
- **SoftHSM2**: Software implementation of a Hardware Security Module
- **Kubernetes**: Container orchestration platform for deployment
- **Helm**: Package manager for Kubernetes applications
- **cert-manager**: Certificate management for Kubernetes

## Repository Structure

