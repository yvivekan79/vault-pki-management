# Vault PKI Infrastructure Architecture

This document outlines the architecture of the Vault PKI infrastructure deployment with SoftHSM2 integration on Kubernetes.

## Overview

The deployment consists of the following key components:

1. **HashiCorp Vault**: A secrets management platform that includes a PKI engine
2. **SoftHSM2**: A software implementation of a Hardware Security Module
3. **Kubernetes**: The underlying container orchestration platform
4. **Raft Storage**: Built-in storage backend for Vault's high availability setup
5. **cert-manager**: An operator to manage certificates within Kubernetes

## Architecture Diagram

