# SoftHSM Integration with Vault

This document provides detailed information on how SoftHSM2 is integrated with HashiCorp Vault in this PKI infrastructure deployment, serving as a software implementation of a Hardware Security Module (HSM) for secure key storage and cryptographic operations.

## Table of Contents

1. [Overview](#overview)
2. [SoftHSM Architecture](#softhsm-architecture)
3. [Integration Components](#integration-components)
4. [Deployment Architecture](#deployment-architecture)
5. [Configuration Details](#configuration-details)
6. [PKCS#11 Interface](#pkcs11-interface)
7. [Key Management](#key-management)
8. [Security Considerations](#security-considerations)
9. [Monitoring and Maintenance](#monitoring-and-maintenance)
10. [Production Recommendations](#production-recommendations)

## Overview

SoftHSM2 is used in this deployment as a software-based HSM that integrates with Vault using the PKCS#11 interface. This integration provides:

- Secure storage for cryptographic keys
- Hardware-like security for key operations
- Protection against key extraction
- Audit trails for key usage
- Support for auto-unsealing Vault

## SoftHSM Architecture

SoftHSM2 is deployed as a DaemonSet in the Kubernetes cluster, ensuring that:

1. Each node in the cluster has a SoftHSM instance available
2. Vault pods can access the SoftHSM regardless of which node they are scheduled on
3. Token data is persistently stored for availability

The SoftHSM deployment includes:

- Token storage using persistent volumes
- Configuration via ConfigMap
- Proper security context and permissions

## Integration Components

The integration between Vault and SoftHSM2 consists of:

1. **PKCS#11 Provider**: SoftHSM2 implements the PKCS#11 interface that Vault uses to interact with HSMs
2. **Seal Configuration**: Vault is configured to use PKCS#11 for seal/unseal operations
3. **Token Initialization**: SoftHSM tokens are initialized during deployment
4. **Library Access**: The Vault container includes the SoftHSM library (`libsofthsm2.so`)

## Deployment Architecture

The SoftHSM integration is deployed using the following components:

1. **SoftHSM DaemonSet**: Ensures SoftHSM is available on all Kubernetes nodes
2. **Persistent Volume**: Stores token data persistently
3. **ConfigMap**: Provides configuration for both Vault and SoftHSM
4. **Init Container**: Initializes the SoftHSM token if needed
5. **Shared Volume Mounts**: Allow the Vault container to access the SoftHSM tokens

```bash
┌───────────────────────┐     ┌───────────────────────┐
│   Kubernetes Node     │     │   Kubernetes Node     │
│                       │     │                       │
│ ┌───────────────────┐ │     │ ┌───────────────────┐ │
│ │   Vault Pod       │ │     │ │   Vault Pod       │ │
│ │                   │ │     │ │                   │ │
│ │ ┌───────────────┐ │ │     │ │ ┌───────────────┐ │ │
│ │ │  Vault Server │ │ │     │ │ │  Vault Server │ │ │
│ │ └──────┬────────┘ │ │     │ │ └──────┬────────┘ │ │
│ │        │          │ │     │ │        │          │ │
│ │        ▼          │ │     │ │        ▼          │ │
│ │ ┌──────────────┐  │ │     │ │ ┌──────────────┐  │ │
│ │ │ PKCS#11 API  │  │ │     │ │ │ PKCS#11 API  │  │ │
│ │ └──────┬───────┘  │ │     │ │ └──────┬───────┘  │ │
│ └────────┼──────────┘ │     │ └────────┼──────────┘ │
│          │            │     │          │            │
│          ▼            │     │          ▼            │
│ ┌────────────────┐    │     │ ┌────────────────┐    │
│ │  SoftHSM Pod   │    │     │ │  SoftHSM Pod   │    │
│ │  (DaemonSet)   │    │     │ │  (DaemonSet)   │    │
│ └────────┬───────┘    │     │ └────────┬───────┘    │
│          │            │     │          │            │
│          ▼            │     │          ▼            │
│ ┌────────────────┐    │     │ ┌────────────────┐    │
│ │  Token Storage │    │     │ │  Token Storage │    │
│ │  (PersistentVolume) │     │ │  (PersistentVolume) │
│ └────────────────┘    │     │ └────────────────┘    │
└───────────────────────┘     └───────────────────────┘
