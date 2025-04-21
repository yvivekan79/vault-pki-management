#!/bin/bash
# Script to configure the PKI backend in Vault

set -e

# Default values - can be overridden with environment variables
VAULT_NAMESPACE=${VAULT_NAMESPACE:-"default"}
VAULT_SERVICE=${VAULT_SERVICE:-"vault-pki"}
VAULT_ADDR="https://${VAULT_SERVICE}.${VAULT_NAMESPACE}.svc:8200"
ROOT_CA_COMMON_NAME=${ROOT_CA_COMMON_NAME:-"Example Root CA"}
INT_CA_COMMON_NAME=${INT_CA_COMMON_NAME:-"Example Intermediate CA"}
PKI_TTL=${PKI_TTL:-"87600h"} # 10 years
INT_TTL=${INT_TTL:-"43800h"} # 5 years
CERT_TTL=${CERT_TTL:-"8760h"} # 1 year
DOMAIN=${DOMAIN:-"example.com"}

# Check if ROOT_TOKEN is set
if [ -z "$VAULT_TOKEN" ]; then
    echo "ERROR: VAULT_TOKEN environment variable is not set."
    echo "Please set it to the root token obtained during initialization."
    echo "Example: export VAULT_TOKEN=hvs...."
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}= Vault PKI Configuration Script        =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in the PATH${NC}"
    exit 1
fi

# Function to execute Vault commands
run_vault_cmd() {
    kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault $1"
}

# Check if the Vault pod is ready
echo -e "${YELLOW}Checking if Vault is ready...${NC}"
POD_NAME=$(kubectl get pods -n ${VAULT_NAMESPACE} -l app.kubernetes.io/name=vault-pki --no-headers -o custom-columns=":metadata.name" | head -1)

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}Error: No Vault pods found. Make sure your Vault deployment is running.${NC}"
    exit 1
fi

echo -e "${GREEN}Using pod: ${POD_NAME}${NC}"

# Check if Vault is initialized and unsealed
echo -e "${YELLOW}Checking Vault status...${NC}"
INIT_STATUS=$(kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- vault status -format=json 2>/dev/null || echo '{"initialized": false, "sealed": true}')
INITIALIZED=$(echo $INIT_STATUS | grep -o '"initialized":[^,}]*' | cut -d ":" -f2 | tr -d ' ')
SEALED=$(echo $INIT_STATUS | grep -o '"sealed":[^,}]*' | cut -d ":" -f2 | tr -d ' ')

if [ "$INITIALIZED" != "true" ]; then
    echo -e "${RED}Vault is not initialized. Please run init-vault.sh first.${NC}"
    exit 1
fi

if [ "$SEALED" == "true" ]; then
    echo -e "${RED}Vault is sealed. Please unseal it first.${NC}"
    exit 1
fi

echo -e "${GREEN}Vault is initialized and unsealed. Proceeding with PKI configuration.${NC}"

# Check if PKI is already enabled
echo -e "${YELLOW}Checking if PKI secrets engines are already enabled...${NC}"
SECRETS_ENGINES=$(run_vault_cmd "secrets list -format=json")
if echo "$SECRETS_ENGINES" | grep -q '"pki/"'; then
    echo -e "${YELLOW}PKI secrets engines appear to be already enabled.${NC}"
    echo -n "Do you want to continue and potentially overwrite existing configuration? (y/N): "
    read CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo -e "${GREEN}Operation aborted.${NC}"
        exit 0
    fi
fi

# Enable and configure the PKI secret engines
echo -e "${YELLOW}Enabling and configuring PKI secret engines...${NC}"

# Enable the root PKI secrets engine
echo -e "${YELLOW}Enabling root PKI secrets engine...${NC}"
run_vault_cmd "secrets enable -path=pki pki"
run_vault_cmd "secrets tune -max-lease-ttl=${PKI_TTL} pki"

# Enable the intermediate PKI secrets engine
echo -e "${YELLOW}Enabling intermediate PKI secrets engine...${NC}"
run_vault_cmd "secrets enable -path=pki_int pki"
run_vault_cmd "secrets tune -max-lease-ttl=${INT_TTL} pki_int"

# Generate the root CA
echo -e "${YELLOW}Generating root CA...${NC}"
run_vault_cmd "write -format=json pki/root/generate/internal \
    common_name=\"${ROOT_CA_COMMON_NAME}\" \
    ttl=${PKI_TTL}" > root_ca.json

echo -e "${GREEN}Root CA generated and saved to root_ca.json${NC}"

# Configure the CA and CRL URLs
echo -e "${YELLOW}Configuring CA and CRL URLs...${NC}"
run_vault_cmd "write pki/config/urls \
    issuing_certificates=\"${VAULT_ADDR}/v1/pki/ca\" \
    crl_distribution_points=\"${VAULT_ADDR}/v1/pki/crl\""

# Generate the intermediate CA CSR
echo -e "${YELLOW}Generating intermediate CA CSR...${NC}"
run_vault_cmd "write -format=json pki_int/intermediate/generate/internal \
    common_name=\"${INT_CA_COMMON_NAME}\" \
    ttl=${INT_TTL}" > intermediate_csr.json

# Extract the CSR
CSR=$(cat intermediate_csr.json | grep -o '"csr":"[^"]*' | cut -d ":" -f2 | tr -d '"')

# Sign the intermediate CSR with the root CA
echo -e "${YELLOW}Signing intermediate CA with root CA...${NC}"
run_vault_cmd "write -format=json pki/root/sign-intermediate \
    csr=\"${CSR}\" \
    format=pem_bundle \
    ttl=${INT_TTL}" > signed_intermediate.json

# Extract the certificate
CERT=$(cat signed_intermediate.json | grep -o '"certificate":"[^"]*' | cut -d ":" -f2 | tr -d '"' | sed 's/\\n/\n/g')

# Import the signed certificate back into the intermediate PKI
echo -e "${YELLOW}Importing signed certificate into intermediate PKI...${NC}"
echo "$CERT" > signed_intermediate.pem
run_vault_cmd "write pki_int/intermediate/set-signed certificate=@-" < signed_intermediate.pem

# Configure the intermediate CA and CRL URLs
echo -e "${YELLOW}Configuring intermediate CA and CRL URLs...${NC}"
run_vault_cmd "write pki_int/config/urls \
    issuing_certificates=\"${VAULT_ADDR}/v1/pki_int/ca\" \
    crl_distribution_points=\"${VAULT_ADDR}/v1/pki_int/crl\""

# Create a role for the intermediate CA
echo -e "${YELLOW}Creating a role for issuing certificates...${NC}"
run_vault_cmd "write pki_int/roles/example-dot-com \
    allowed_domains=\"${DOMAIN}\" \
    allow_subdomains=true \
    max_ttl=${CERT_TTL}"

# Create a policy for the PKI
echo -e "${YELLOW}Creating PKI policy...${NC}"
POLICY=$(cat <<EOF
path "pki*"                               { capabilities = ["read", "list"] }
path "pki_int/issue/*"                    { capabilities = ["create", "update"] }
path "pki_int/certs"                      { capabilities = ["list"] }
path "pki_int/revoke"                     { capabilities = ["create", "update"] }
path "pki_int/tidy"                       { capabilities = ["create", "update"] }
path "pki/cert/ca"                        { capabilities = ["read"] }
path "pki_int/cert/ca"                    { capabilities = ["read"] }
path "auth/token/renew"                   { capabilities = ["update"] }
path "auth/token/renew-self"              { capabilities = ["update"] }
EOF
)

echo "$POLICY" > pki-policy.hcl
run_vault_cmd "policy write pki-policy -" < pki-policy.hcl

# Create a token for the PKI policy
echo -e "${YELLOW}Creating a token for the PKI policy...${NC}"
TOKEN_JSON=$(run_vault_cmd "token create -policy=pki-policy -format=json")
PKI_TOKEN=$(echo "$TOKEN_JSON" | grep -o '"client_token":"[^"]*' | cut -d ":" -f2 | tr -d '"')

# Save the token to a file
echo "$PKI_TOKEN" > pki-token.txt
echo -e "${GREEN}PKI token saved to pki-token.txt${NC}"

# Test certificate issuing
echo -e "${YELLOW}Testing certificate issuance...${NC}"
TEST_CERT=$(run_vault_cmd "write -format=json pki_int/issue/example-dot-com \
    common_name=test.${DOMAIN} \
    ttl=720h")

echo "$TEST_CERT" > test-cert.json
echo -e "${GREEN}Test certificate issued and saved to test-cert.json${NC}"

# Print success message
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}= PKI Configuration Complete!           =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo
echo -e "${YELLOW}The following files were created:${NC}"
echo "- root_ca.json: Contains the root CA certificate"
echo "- intermediate_csr.json: Contains the intermediate CA CSR"
echo "- signed_intermediate.json: Contains the signed intermediate certificate"
echo "- signed_intermediate.pem: The PEM-formatted signed intermediate certificate"
echo "- pki-policy.hcl: The policy for the PKI"
echo "- pki-token.txt: A token with the PKI policy attached"
echo "- test-cert.json: A test certificate issued by the intermediate CA"
echo
echo -e "${YELLOW}To use the PKI from the command line:${NC}"
echo "export VAULT_ADDR=${VAULT_ADDR}"
echo "export VAULT_TOKEN=${PKI_TOKEN}"
echo "export VAULT_SKIP_VERIFY=true  # Only for self-signed certificates"
echo
echo -e "${YELLOW}To issue a new certificate:${NC}"
echo "vault write pki_int/issue/example-dot-com common_name=hostname.${DOMAIN} ttl=720h"
echo
echo -e "${GREEN}Your Vault PKI infrastructure is now ready for use!${NC}"
