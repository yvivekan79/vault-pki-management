# Vault server configuration

ui = true

# TCP listener for client API
listener "tcp" {
  address = "[::]:8200"
  cluster_address = "[::]:8201"
  
  # TLS configuration
  tls_disable = false
  tls_cert_file = "/vault/tls/tls.crt"
  tls_key_file = "/vault/tls/tls.key"
}

# Raft storage backend for high availability
storage "raft" {
  path = "/vault/data"
  node_id = "${POD_NAME}"
  
  retry_join {
    leader_api_addr = "https://vault-pki-0.vault-pki-internal:8200"
    leader_tls_servername = "vault-pki"
    leader_ca_cert_file = "/vault/tls/ca.crt"
    leader_client_cert_file = "/vault/tls/tls.crt"
    leader_client_key_file = "/vault/tls/tls.key"
  }
}

# PKCS#11 (HSM) integration
seal "pkcs11" {
  lib = "/usr/lib/softhsm/libsofthsm2.so"
  slot = "0"
  pin = "1234"
  key_label = "vault-hsm-key"
  hmac_key_label = "vault-hsm-hmac-key"
}

# API and cluster addresses
api_addr = "https://vault-pki.${NAMESPACE}.svc:8200"
cluster_addr = "https://${POD_NAME}.vault-pki-internal:8201"

# Additional settings
log_level = "info"
disable_mlock = true

# Telemetry for monitoring
telemetry {
  statsd_address = "localhost:9125"
  disable_hostname = true
}
