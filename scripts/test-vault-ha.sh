#!/bin/bash
# Script to test Vault high availability features

set -e

# Default values
VAULT_NAMESPACE=${VAULT_NAMESPACE:-"default"}
VAULT_SERVICE=${VAULT_SERVICE:-"vault-pki"}
VAULT_ADDR="https://${VAULT_SERVICE}.${VAULT_NAMESPACE}.svc:8200"

# Check if VAULT_TOKEN is set
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
echo -e "${GREEN}= Vault High Availability Test Script    =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in the PATH${NC}"
    exit 1
fi

# Get all Vault pods
echo -e "${YELLOW}Getting Vault pods...${NC}"
VAULT_PODS=$(kubectl get pods -n ${VAULT_NAMESPACE} -l app.kubernetes.io/name=vault-pki --no-headers -o custom-columns=":metadata.name")

if [ -z "$VAULT_PODS" ]; then
    echo -e "${RED}Error: No Vault pods found. Make sure your Vault deployment is running.${NC}"
    exit 1
fi

echo -e "${GREEN}Found Vault pods:${NC}"
echo "$VAULT_PODS"

# Count the number of pods
POD_COUNT=$(echo "$VAULT_PODS" | wc -l)
echo -e "${GREEN}Total number of Vault pods: ${POD_COUNT}${NC}"

# Function to get Vault status from a pod
get_vault_status() {
    local pod_name=$1
    kubectl exec -n ${VAULT_NAMESPACE} ${pod_name} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault status -format=json" 2>/dev/null || echo '{"sealed": true, "ha_enabled": false}'
}

# Function to check if a pod is a leader
is_leader() {
    local status=$1
    echo $status | grep -q '"ha_enabled":true' && echo $status | grep -q '"leader":true'
}

# Check all pods and find the leader
echo -e "${YELLOW}Checking Vault cluster status...${NC}"
leader_found=false
leader_pod=""

for pod in $VAULT_PODS; do
    echo -e "${YELLOW}Checking status of pod: ${pod}${NC}"
    status=$(get_vault_status $pod)
    
    sealed=$(echo $status | grep -o '"sealed":[^,}]*' | cut -d ":" -f2 | tr -d ' ')
    ha_enabled=$(echo $status | grep -o '"ha_enabled":[^,}]*' | cut -d ":" -f2 | tr -d ' ')
    
    echo -e "  Sealed: ${sealed}"
    echo -e "  HA Enabled: ${ha_enabled}"
    
    if is_leader "$status"; then
        leader_found=true
        leader_pod=$pod
        echo -e "  ${GREEN}This pod is the LEADER${NC}"
    else
        if [ "$sealed" == "false" ]; then
            echo -e "  ${GREEN}This pod is a STANDBY${NC}"
        else
            echo -e "  ${RED}This pod is SEALED${NC}"
        fi
    fi
done

if [ "$leader_found" == "true" ]; then
    echo -e "${GREEN}Success! Vault HA cluster is properly configured.${NC}"
    echo -e "${GREEN}Leader pod: ${leader_pod}${NC}"
else
    echo -e "${RED}No leader found in the Vault cluster. The cluster may not be properly initialized or all nodes are sealed.${NC}"
    exit 1
fi

# Test failover by stepping down the leader
echo -e "${YELLOW}Testing failover by stepping down the current leader...${NC}"
echo -n "Do you want to proceed with failover testing? (y/N): "
read CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${GREEN}Failover testing skipped.${NC}"
    exit 0
fi

echo -e "${YELLOW}Stepping down leader pod: ${leader_pod}${NC}"
kubectl exec -n ${VAULT_NAMESPACE} ${leader_pod} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator step-down"
echo -e "${GREEN}Leader step-down initiated. Waiting for new leader election...${NC}"

# Sleep to allow leader election
sleep 5

# Check all pods again to find the new leader
echo -e "${YELLOW}Checking for new leader...${NC}"
new_leader_found=false
new_leader_pod=""

for pod in $VAULT_PODS; do
    echo -e "${YELLOW}Checking status of pod: ${pod}${NC}"
    status=$(get_vault_status $pod)
    
    if is_leader "$status"; then
        new_leader_found=true
        new_leader_pod=$pod
        echo -e "  ${GREEN}This pod is the NEW LEADER${NC}"
    else
        sealed=$(echo $status | grep -o '"sealed":[^,}]*' | cut -d ":" -f2 | tr -d ' ')
        if [ "$sealed" == "false" ]; then
            echo -e "  ${GREEN}This pod is a STANDBY${NC}"
        else
            echo -e "  ${RED}This pod is SEALED${NC}"
        fi
    fi
done

if [ "$new_leader_found" == "true" ]; then
    echo -e "${GREEN}Success! Vault HA failover worked correctly.${NC}"
    echo -e "${GREEN}Previous leader: ${leader_pod}${NC}"
    echo -e "${GREEN}New leader: ${new_leader_pod}${NC}"
else
    echo -e "${RED}No new leader found after step-down. Failover may have failed.${NC}"
    exit 1
fi

# Test writing and reading a secret to verify functionality
echo -e "${YELLOW}Testing write/read functionality after failover...${NC}"
TEST_KEY="test-ha-$(date +%s)"
TEST_VALUE="value-$(date +%s)"

# Enable the KV secrets engine if it's not already enabled
echo -e "${YELLOW}Making sure the KV secrets engine is enabled...${NC}"
kubectl exec -n ${VAULT_NAMESPACE} ${new_leader_pod} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault secrets list -format=json" | grep -q '"kv/"' || \
kubectl exec -n ${VAULT_NAMESPACE} ${new_leader_pod} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault secrets enable -version=2 kv"

# Write a test secret
echo -e "${YELLOW}Writing test secret...${NC}"
kubectl exec -n ${VAULT_NAMESPACE} ${new_leader_pod} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault kv put kv/${TEST_KEY} value=${TEST_VALUE}"

# Read the test secret from a different pod (if available)
read_pod=${new_leader_pod}
for pod in $VAULT_PODS; do
    if [ "$pod" != "$new_leader_pod" ]; then
        read_pod=$pod
        break
    fi
done

echo -e "${YELLOW}Reading test secret from pod: ${read_pod}${NC}"
SECRET_VALUE=$(kubectl exec -n ${VAULT_NAMESPACE} ${read_pod} -- sh -c "VAULT_TOKEN=${VAULT_TOKEN} VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault kv get -format=json kv/${TEST_KEY}")

if echo "$SECRET_VALUE" | grep -q "\"${TEST_VALUE}\""; then
    echo -e "${GREEN}Success! Secret was successfully written and read across the cluster.${NC}"
else
    echo -e "${RED}Failed to verify the test secret.${NC}"
    echo "Secret response: $SECRET_VALUE"
    exit 1
fi

# Print summary
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}= Vault HA Test Complete - SUCCESSFUL!   =${NC}"
echo -e "${GREEN}==========================================${NC}"
echo
echo -e "${YELLOW}Summary:${NC}"
echo "- Verified Vault HA cluster with ${POD_COUNT} nodes"
echo "- Successfully performed leader step-down and failover"
echo "- Confirmed data replication across the cluster"
echo
echo -e "${GREEN}Your Vault cluster is properly configured for high availability!${NC}"
