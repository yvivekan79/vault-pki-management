# Vault PKI Management API Specification

This document provides detailed information on the RESTful API endpoints available for managing the Vault PKI infrastructure. These APIs can be used for automation, integration with other systems, and programmatic access to PKI functionality.

## Base URL

All API endpoints are relative to the base URL:
```
https://your-vault-pki-manager.com/api/v1
```

## Authentication

For production environments, authentication would typically be implemented. However, in this demo version, no authentication is required for simplicity.

In a production environment, you would typically include an API key or token in the request headers:
```
Authorization: Bearer your-api-token
```

## Certificates

### List All Certificates

Retrieves a list of all certificates managed by the system.

- **URL**: `/certificates`
- **Method**: `GET`
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "certificates": [
    {
      "id": 1,
      "name": "root-ca",
      "common_name": "Vault Root CA",
      "issuer": "Self",
      "valid_from": "2025-03-22T00:00:00Z",
      "valid_until": "2035-03-22T00:00:00Z",
      "status": "valid",
      "created_at": "2025-04-21T09:00:00Z"
    },
    {
      "id": 2,
      "name": "intermediate-ca",
      "common_name": "Vault Intermediate CA",
      "issuer": "Vault Root CA",
      "valid_from": "2025-04-06T00:00:00Z",
      "valid_until": "2030-04-06T00:00:00Z",
      "status": "valid",
      "created_at": "2025-04-21T09:00:00Z"
    }
  ]
}
```

### Get Certificate Details

Retrieves details for a specific certificate.

- **URL**: `/certificates/{certificate_id}`
- **Method**: `GET`
- **URL Parameters**: 
  - `certificate_id` - ID of the certificate to retrieve
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "id": 1,
  "name": "root-ca",
  "common_name": "Vault Root CA",
  "issuer": "Self",
  "valid_from": "2025-03-22T00:00:00Z",
  "valid_until": "2035-03-22T00:00:00Z",
  "status": "valid",
  "created_at": "2025-04-21T09:00:00Z"
}
```

### Issue Certificate

Issues a new certificate based on the provided parameters.

- **URL**: `/certificates/issue`
- **Method**: `POST`
- **Data Params**:
```json
{
  "common_name": "api.example.com",
  "ttl": "8760h",
  "role": "server",
  "alt_names": "www.example.com,example.com",
  "ip_sans": "10.0.0.1,192.168.1.10",
  "key_type": "rsa",
  "key_bits": 2048
}
```
- **Required Fields**:
  - `common_name` - The common name for the certificate
  - `ttl` - Time to live in format like "8760h" for 1 year
  - `role` - Role to use for issuing the certificate (e.g., "server", "client", "peer")
- **Optional Fields**:
  - `alt_names` - Comma-separated list of subject alternative names
  - `ip_sans` - Comma-separated list of IP addresses to include as SANs
  - `key_type` - Key type (default: "rsa")
  - `key_bits` - Key size in bits (default: 2048)
  - `name` - Custom name for the certificate

- **Response**: 
  - **Code**: 201 Created
  - **Content**:
```json
{
  "success": true,
  "certificate_id": 5,
  "certificate": {
    "id": 5,
    "name": "api-example-com-20250421",
    "common_name": "api.example.com",
    "issuer": "Vault Intermediate CA",
    "valid_from": "2025-04-21T10:00:00Z",
    "valid_until": "2026-04-21T10:00:00Z",
    "status": "valid"
  },
  "message": "Certificate issued successfully. In a production environment, this would return the actual certificate data."
}
```

### Revoke Certificate

Revokes a specific certificate.

- **URL**: `/certificates/{certificate_id}/revoke`
- **Method**: `POST`
- **URL Parameters**: 
  - `certificate_id` - ID of the certificate to revoke
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "success": true,
  "certificate_id": 5,
  "status": "revoked",
  "message": "Certificate revoked successfully"
}
```

## Vault Servers

### List All Servers

Retrieves a list of all Vault servers in the cluster.

- **URL**: `/servers`
- **Method**: `GET`
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "servers": [
    {
      "id": 1,
      "name": "vault-0",
      "address": "vault-0.vault-internal:8200",
      "status": "healthy",
      "sealed": false,
      "version": "1.14.0",
      "last_checked": "2025-04-21T09:00:00Z"
    },
    {
      "id": 2,
      "name": "vault-1",
      "address": "vault-1.vault-internal:8200",
      "status": "healthy",
      "sealed": false,
      "version": "1.14.0",
      "last_checked": "2025-04-21T09:00:00Z"
    }
  ]
}
```

### Get Server Details

Retrieves details for a specific Vault server.

- **URL**: `/servers/{server_id}`
- **Method**: `GET`
- **URL Parameters**: 
  - `server_id` - ID of the server to retrieve
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "id": 1,
  "name": "vault-0",
  "address": "vault-0.vault-internal:8200",
  "status": "healthy",
  "sealed": false,
  "version": "1.14.0",
  "last_checked": "2025-04-21T09:00:00Z"
}
```

### Unseal Server

Unseals a Vault server.

- **URL**: `/servers/{server_id}/unseal`
- **Method**: `POST`
- **URL Parameters**: 
  - `server_id` - ID of the server to unseal
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "success": true,
  "server_id": 1,
  "sealed": false,
  "message": "Server unsealed successfully"
}
```

## Health Check

### Check API Health

Checks the health of the API service.

- **URL**: `/health`
- **Method**: `GET`
- **Response**: 
  - **Code**: 200 OK
  - **Content**:
```json
{
  "status": "healthy"
}
```

## Error Responses

When an error occurs, the API will return an appropriate HTTP status code and a JSON response with details about the error:

```json
{
  "error": "Invalid request: Missing required field 'common_name'"
}
```

Common error codes:
- `400 Bad Request` - The request was invalid
- `404 Not Found` - The requested resource was not found
- `500 Internal Server Error` - An unexpected error occurred on the server