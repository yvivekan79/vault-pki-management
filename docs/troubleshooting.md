# Troubleshooting Guide

This guide provides solutions to common issues you might encounter with the Vault PKI infrastructure deployment with SoftHSM integration on Kubernetes.

## Table of Contents

1. [Deployment Issues](#deployment-issues)
2. [Vault Initialization Issues](#vault-initialization-issues)
3. [Vault Unsealing Issues](#vault-unsealing-issues)
4. [SoftHSM Integration Issues](#softhsm-integration-issues)
5. [High Availability Issues](#high-availability-issues)
6. [PKI Certificate Issues](#pki-certificate-issues)
7. [TLS Issues](#tls-issues)
8. [Persistent Storage Issues](#persistent-storage-issues)
9. [Performance Issues](#performance-issues)
10. [Logs and Debugging](#logs-and-debugging)

## Deployment Issues

### Problem: Helm Chart Installation Fails

**Symptoms:**
- Helm installation reports errors
- Resources are not created in the cluster

**Solutions:**
1. Verify Helm version is 3.0 or later:
   ```bash
   helm version
   