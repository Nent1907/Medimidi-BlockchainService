#!/bin/bash
#
# Medical Diagnosis Blockchain - Chaincode Deployment Script (RAFT)
# Deploys the medical-diagnosis-chaincode with RAFT consensus
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Chaincode configuration
CHAINCODE_NAME=medical-diagnosis-chaincode
CHAINCODE_VERSION=1.0
CHAINCODE_SEQUENCE=1
CHANNEL_NAME=medimidi-channel
CHAINCODE_PATH=/opt/gopath/src/github.com/chaincode/medical-diagnosis
ORDERER_ADDRESS=orderer0.medimidi.com:7050

echo -e "${BLUE}🏥 Medical Diagnosis Chaincode Deployment (RAFT)${NC}"
echo -e "${BLUE}=================================================${NC}"

# Change to project root
cd "$PROJECT_ROOT"

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Package chaincode
print_message "Packaging chaincode..."
docker exec cli peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz \
    --path ${CHAINCODE_PATH} \
    --lang golang \
    --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}

if [ $? -eq 0 ]; then
    print_message "✅ Chaincode packaged successfully"
else
    print_error "❌ Failed to package chaincode"
    exit 1
fi

# Install chaincode on Org1 peer
print_message "Installing chaincode on Org1 peer..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz

# Install chaincode on Org2 peer
print_message "Installing chaincode on Org2 peer..."
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/peers/peer0.org2.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/users/Admin@org2.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org2.medimidi.com:9051 \
            cli peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz

# Get package ID
print_message "Querying installed chaincodes to get package ID..."
PACKAGE_ID=$(docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
                        -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
                        -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
                        -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
                        cli peer lifecycle chaincode queryinstalled | grep ${CHAINCODE_NAME}_${CHAINCODE_VERSION} | cut -d' ' -f3 | cut -d',' -f1)

if [ -z "$PACKAGE_ID" ]; then
    print_error "❌ Failed to get chaincode package ID"
    exit 1
fi

print_message "📦 Chaincode Package ID: $PACKAGE_ID"

# Approve chaincode for Org1
print_message "Approving chaincode definition for Org1..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer lifecycle chaincode approveformyorg \
                -o ${ORDERER_ADDRESS} \
                --channelID ${CHANNEL_NAME} \
                --name ${CHAINCODE_NAME} \
                --version ${CHAINCODE_VERSION} \
                --package-id ${PACKAGE_ID} \
                --sequence ${CHAINCODE_SEQUENCE} \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

# Approve chaincode for Org2
print_message "Approving chaincode definition for Org2..."
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/peers/peer0.org2.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/users/Admin@org2.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org2.medimidi.com:9051 \
            cli peer lifecycle chaincode approveformyorg \
                -o ${ORDERER_ADDRESS} \
                --channelID ${CHANNEL_NAME} \
                --name ${CHAINCODE_NAME} \
                --version ${CHAINCODE_VERSION} \
                --package-id ${PACKAGE_ID} \
                --sequence ${CHAINCODE_SEQUENCE} \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

# Check commit readiness
print_message "Checking commit readiness..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer lifecycle chaincode checkcommitreadiness \
                --channelID ${CHANNEL_NAME} \
                --name ${CHAINCODE_NAME} \
                --version ${CHAINCODE_VERSION} \
                --sequence ${CHAINCODE_SEQUENCE} \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem \
                --output json

# Commit chaincode definition
print_message "Committing chaincode definition to channel..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer lifecycle chaincode commit \
                -o ${ORDERER_ADDRESS} \
                --channelID ${CHANNEL_NAME} \
                --name ${CHAINCODE_NAME} \
                --version ${CHAINCODE_VERSION} \
                --sequence ${CHAINCODE_SEQUENCE} \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem \
                --peerAddresses peer0.org1.medimidi.com:7051 \
                --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
                --peerAddresses peer0.org2.medimidi.com:9051 \
                --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/peers/peer0.org2.medimidi.com/tls/ca.crt

if [ $? -eq 0 ]; then
    print_message "✅ Chaincode committed successfully to RAFT cluster"
else
    print_error "❌ Failed to commit chaincode"
    exit 1
fi

# Query committed chaincodes
print_message "Querying committed chaincodes..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer lifecycle chaincode querycommitted \
                --channelID ${CHANNEL_NAME} \
                --name ${CHAINCODE_NAME} \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

# Test chaincode invocation
print_message "Testing chaincode invocation..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer chaincode invoke \
                -o ${ORDERER_ADDRESS} \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem \
                -C ${CHANNEL_NAME} \
                -n ${CHAINCODE_NAME} \
                --peerAddresses peer0.org1.medimidi.com:7051 \
                --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
                --peerAddresses peer0.org2.medimidi.com:9051 \
                --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/peers/peer0.org2.medimidi.com/tls/ca.crt \
                -c '{"function":"InitLedger","Args":[]}'

echo
print_message "🎉 Chaincode deployment completed successfully!"
print_message "✅ RAFT consensus is handling chaincode transactions"
print_message "✅ Medical diagnosis chaincode is ready for use"

echo
print_message "Deployment Summary:"
print_message "  - Chaincode Name: ${CHAINCODE_NAME}"
print_message "  - Version: ${CHAINCODE_VERSION}"
print_message "  - Channel: ${CHANNEL_NAME}"
print_message "  - Consensus: RAFT (2 orderers)"
print_message "  - Package ID: ${PACKAGE_ID}"

echo
print_message "Next step: Start the API server with 'cd api && npm install && npm start'"
