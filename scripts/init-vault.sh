#!/bin/bash
# Script to initialize a Vault cluster and set up auto-unsealing

set -e

# Default values - can be overridden with environment variables
VAULT_NAMESPACE=${VAULT_NAMESPACE:-"default"}
VAULT_SERVICE=${VAULT_SERVICE:-"vault-pki"}
KEY_SHARES=${KEY_SHARES:-5}
KEY_THRESHOLD=${KEY_THRESHOLD:-3}
VAULT_ADDR="https://${VAULT_SERVICE}.${VAULT_NAMESPACE}.svc:8200"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}= Vault PKI Initialization Script       =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in the PATH${NC}"
    exit 1
fi

# Check if the Vault pod is ready
echo -e "${YELLOW}Checking if Vault is ready...${NC}"
POD_NAME=$(kubectl get pods -n ${VAULT_NAMESPACE} -l app.kubernetes.io/name=vault-pki --no-headers -o custom-columns=":metadata.name" | head -1)

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}Error: No Vault pods found. Make sure your Vault deployment is running.${NC}"
    exit 1
fi

echo -e "${GREEN}Using pod: ${POD_NAME}${NC}"

# Check if Vault is already initialized
echo -e "${YELLOW}Checking if Vault is already initialized...${NC}"
INIT_STATUS=$(kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- vault status -format=json 2>/dev/null || echo '{"initialized": false}')
INITIALIZED=$(echo $INIT_STATUS | grep -o '"initialized":[^,}]*' | cut -d ":" -f2 | tr -d ' ')

if [ "$INITIALIZED" == "true" ]; then
    echo -e "${GREEN}Vault is already initialized.${NC}"
    
    # Check if Vault is sealed
    SEALED=$(echo $INIT_STATUS | grep -o '"sealed":[^,}]*' | cut -d ":" -f2 | tr -d ' ')
    if [ "$SEALED" == "true" ]; then
        echo -e "${YELLOW}Vault is sealed. Manual unsealing is required.${NC}"
        echo "Please retrieve your unseal keys and run the following command for each key (you need at least ${KEY_THRESHOLD}):"
        echo "kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- vault operator unseal <unseal_key>"
    else
        echo -e "${GREEN}Vault is already unsealed and ready for use.${NC}"
    fi
    exit 0
fi

# Initialize Vault
echo -e "${YELLOW}Initializing Vault...${NC}"
INIT_OUTPUT=$(kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- vault operator init \
    -key-shares=${KEY_SHARES} \
    -key-threshold=${KEY_THRESHOLD} \
    -format=json)

# Save the unseal keys and root token
KEYS_FILE="vault-keys-$(date +%Y%m%d%H%M%S).json"
echo "$INIT_OUTPUT" > $KEYS_FILE
echo -e "${GREEN}Vault initialization completed. Keys and tokens saved to ${KEYS_FILE}${NC}"
echo -e "${YELLOW}IMPORTANT: Keep this file secure and backed up. It contains sensitive data.${NC}"

# Extract keys and token for unsealing
UNSEAL_KEYS=$(echo "$INIT_OUTPUT" | grep -o '"unseal_keys_b64":\[[^]]*\]' | cut -d ":" -f2 | tr -d '[]"' | tr ',' '\n')
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | grep -o '"root_token":"[^"]*' | cut -d ":" -f2 | tr -d '"')

# Unseal Vault
echo -e "${YELLOW}Unsealing Vault...${NC}"
i=0
for key in $UNSEAL_KEYS; do
    if [ $i -lt $KEY_THRESHOLD ]; then
        echo -e "${YELLOW}Using unseal key $((i+1))...${NC}"
        kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- vault operator unseal $key
        i=$((i+1))
    else
        break
    fi
done

# Set up environment with root token
echo -e "${YELLOW}Setting up Vault with root token...${NC}"
kubectl exec -n ${VAULT_NAMESPACE} ${POD_NAME} -- sh -c "VAULT_TOKEN=$ROOT_TOKEN VAULT_ADDR=https://127.0.0.1:8200 vault status"

echo -e "${GREEN}Vault is now initialized and unsealed!${NC}"
echo
echo -e "${YELLOW}To access Vault, use:${NC}"
echo "export VAULT_ADDR=${VAULT_ADDR}"
echo "export VAULT_TOKEN=${ROOT_TOKEN}"
echo "export VAULT_SKIP_VERIFY=true  # Only for self-signed certificates"
echo
echo -e "${YELLOW}For production use, you should set up proper TLS verification.${NC}"
echo
echo -e "${GREEN}Now you can run ./configure-pki.sh to set up the PKI backend.${NC}"
