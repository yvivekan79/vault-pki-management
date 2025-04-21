# Vault PKI Deployment Guide

This guide provides step-by-step instructions for deploying the highly available Vault PKI infrastructure with SoftHSM2 integration on Kubernetes.

## Prerequisites

Before you begin, ensure you have the following:

1. A Kubernetes cluster (v1.19 or later)
2. Helm 3 installed and configured
3. `kubectl` configured to communicate with your cluster
4. Administrative access to the cluster
5. Storage classes available for persistent volumes
6. RBAC permissions to create ServiceAccounts, Roles, and RoleBindings

## Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/vault-pki-infrastructure.git
cd vault-pki-infrastructure
