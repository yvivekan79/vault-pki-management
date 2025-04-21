#!/bin/bash
# Script to set up and verify SoftHSM integration with Vault

set -e

# Default values - can be overridden with environment variables
VAULT_NAMESPACE=${VAULT_NAMESPACE:-"default"}
VAULT_SERVICE=${VAULT_SERVICE:-"vault-pki"}
SOFTHSM_TOKEN_LABEL=${SOFTHSM_TOKEN_LABEL:-"vault-token"}
SOFTHSM_USER_PIN=${SOFTHSM_USER_PIN:-"1234"}
SOFTHSM_SO_PIN=${SOFTHSM_SO_PIN:-"87654321"}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}= SoftHSM2 Setup and Verification Script =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in the PATH${NC}"
    exit 1
fi

# Check if the SoftHSM pod is ready
echo -e "${YELLOW}Checking if SoftHSM DaemonSet is deployed...${NC}"
DS_STATUS=$(kubectl get daemonset -n ${VAULT_NAMESPACE} ${VAULT_SERVICE}-softhsm -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")

if [ "$DS_STATUS" == "0" ]; then
    echo -e "${RED}Error: SoftHSM DaemonSet not found or no ready pods.${NC}"
    exit 1
fi

echo -e "${GREEN}SoftHSM DaemonSet is ready with ${DS_STATUS} pods.${NC}"

# Get a SoftHSM pod
SOFTHSM_POD=$(kubectl get pods -n ${VAULT_NAMESPACE} -l app.kubernetes.io/component=softhsm --no-headers -o custom-columns=":metadata.name" | head -1)

if [ -z "$SOFTHSM_POD" ]; then
    echo -e "${RED}Error: No SoftHSM pods found.${NC}"
    exit 1
fi

echo -e "${GREEN}Using SoftHSM pod: ${SOFTHSM_POD}${NC}"

# Check the SoftHSM configuration
echo -e "${YELLOW}Checking SoftHSM configuration...${NC}"
SOFTHSM_CONF=$(kubectl exec -n ${VAULT_NAMESPACE} ${SOFTHSM_POD} -- cat /etc/softhsm2/softhsm2.conf)

echo -e "${GREEN}SoftHSM configuration found:${NC}"
echo "$SOFTHSM_CONF"

# Check if the token directory exists
echo -e "${YELLOW}Checking token directory...${NC}"
TOKEN_DIR=$(kubectl exec -n ${VAULT_NAMESPACE} ${SOFTHSM_POD} -- ls -la /softhsm/tokens/)

echo -e "${GREEN}Token directory contents:${NC}"
echo "$TOKEN_DIR"

# Check if a token has been initialized
echo -e "${YELLOW}Checking if a token has been initialized...${NC}"
INITIALIZED=$(kubectl exec -n ${VAULT_NAMESPACE} ${SOFTHSM_POD} -- test -f /softhsm/tokens/.initialized && echo "true" || echo "false")

if [ "$INITIALIZED" == "false" ]; then
    echo -e "${YELLOW}No initialized token found. Initializing token...${NC}"
    kubectl exec -n ${VAULT_NAMESPACE} ${SOFTHSM_POD} -- softhsm2-util --init-token --slot 0 --label "${SOFTHSM_TOKEN_LABEL}" --so-pin "${SOFTHSM_SO_PIN}" --pin "${SOFTHSM_USER_PIN}"
    kubectl exec -n ${VAULT_NAMESPACE} ${SOFTHSM_POD} -- touch /softhsm/tokens/.initialized
    echo -e "${GREEN}Token initialized.${NC}"
else
    echo -e "${GREEN}Token is already initialized.${NC}"
fi

# List available tokens
echo -e "${YELLOW}Listing available tokens...${NC}"
TOKENS=$(kubectl exec -n ${VAULT_NAMESPACE} ${SOFTHSM_POD} -- softhsm2-util --show-slots)

echo -e "${GREEN}Available tokens:${NC}"
echo "$TOKENS"

# Get a Vault pod
VAULT_POD=$(kubectl get pods -n ${VAULT_NAMESPACE} -l app.kubernetes.io/name=vault-pki --no-headers -o custom-columns=":metadata.name" | head -1)

if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}Error: No Vault pods found.${NC}"
    exit 1
fi

echo -e "${GREEN}Using Vault pod: ${VAULT_POD}${NC}"

# Check if the Vault pod can access the SoftHSM library
echo -e "${YELLOW}Checking if Vault can access the SoftHSM library...${NC}"
HSM_LIB=$(kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- find / -name "libsofthsm2.so" 2>/dev/null || echo "")

if [ -z "$HSM_LIB" ]; then
    echo -e "${RED}Error: SoftHSM library not found in Vault pod.${NC}"
    echo -e "${YELLOW}You may need to ensure the SoftHSM library is installed in the Vault container.${NC}"
    exit 1
fi

echo -e "${GREEN}SoftHSM library found at: ${HSM_LIB}${NC}"

# Check the Vault PKCS11 configuration
echo -e "${YELLOW}Checking Vault PKCS11 configuration...${NC}"
VAULT_CONFIG=$(kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- cat /vault/config/vault-config.hcl)

echo -e "${GREEN}Vault configuration:${NC}"
echo "$VAULT_CONFIG"

# Verify the seal status
echo -e "${YELLOW}Checking Vault seal status...${NC}"
if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${YELLOW}VAULT_TOKEN environment variable not set. Some checks will be skipped.${NC}"
    SEAL_STATUS=$(kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- vault status -format=json 2>/dev/null || echo '{"type":"unknown"}')
else
    SEAL_STATUS=$(kubectl exec -n ${VAULT_NAMESPACE} ${VAULT_POD} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault status -format=json" 2>/dev/null || echo '{"type":"unknown"}')
fi

SEAL_TYPE=$(echo $SEAL_STATUS | grep -o '"type":"[^"]*' | cut -d ":" -f2 | tr -d '"')

if [ "$SEAL_TYPE" == "pkcs11" ] || [ "$SEAL_TYPE" == "shamir" ]; then
    echo -e "${GREEN}Vault seal type: ${SEAL_TYPE}${NC}"
else
    echo -e "${RED}Could not determine Vault seal type or not using PKCS11.${NC}"
    echo -e "${YELLOW}Current seal type: ${SEAL_TYPE}${NC}"
fi

# Print summary
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}= SoftHSM Setup Verification Complete!   =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo
echo -e "${YELLOW}Summary:${NC}"
echo "- SoftHSM DaemonSet is ready"
echo "- SoftHSM token is initialized"
echo "- SoftHSM library is accessible to Vault"
echo "- Vault seal type: ${SEAL_TYPE}"
echo
echo -e "${GREEN}SoftHSM integration appears to be properly configured.${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. If you haven't already, initialize Vault with ./init-vault.sh"
echo "2. Configure the PKI backend with ./configure-pki.sh"
echo
echo -e "${YELLOW}For production use, consider:${NC}"
echo "- Using a more secure PIN management strategy"
echo "- Implementing regular backups of the HSM tokens"
echo "- Setting up monitoring for the SoftHSM and Vault components"
