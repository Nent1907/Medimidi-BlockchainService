#!/bin/bash
#
# Tıbbi Tanı Blockchain - Kanal Oluşturma Scripti (RAFT)
# RAFT konsensüs ile medical-channel oluşturur
#

set -e

# Çıktı için renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Renk Yok

# Script dizini
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Kanal konfigürasyonu
CHANNEL_NAME=medimidi-channel
ORDERER_ADDRESS=orderer0.medimidi.com:7050
ORDERER_CA=${PROJECT_ROOT}/network/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

echo -e "${BLUE}🏥 Medical Diagnosis Channel Creation (RAFT)${NC}"
echo -e "${BLUE}=============================================${NC}"

# Proje kök dizinine geç
cd "$PROJECT_ROOT"

# Renkli mesajlar yazdırmak için fonksiyon
print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# configtxgen'in mevcut olup olmadığını kontrol et
if ! command -v configtxgen &> /dev/null; then
    print_error "configtxgen not found. Please ensure Fabric binaries are in PATH"
    exit 1
fi

# CLI için ortam değişkenlerini ayarla
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_ROOT}/network/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_ROOT}/network/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp
export CORE_PEER_ADDRESS=localhost:7051
export FABRIC_CFG_PATH=${PROJECT_ROOT}/network/configtx

print_message "Creating channel configuration transaction..."
configtxgen -profile MedicalChannel -outputCreateChannelTx ./network/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}

if [ ! -f "./network/${CHANNEL_NAME}.tx" ]; then
    print_error "Failed to create channel configuration transaction"
    exit 1
fi

print_message "Channel configuration transaction created successfully"

print_message "Creating channel '${CHANNEL_NAME}' on RAFT orderer cluster..."

# Use docker exec to run peer command inside CLI container with admin identity
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ENABLED=true \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer channel create \
    -o ${ORDERER_ADDRESS} \
    -c ${CHANNEL_NAME} \
    -f /opt/gopath/src/github.com/hyperledger/fabric/peer/network/${CHANNEL_NAME}.tx \
    --outputBlock /opt/gopath/src/github.com/hyperledger/fabric/peer/network/${CHANNEL_NAME}.block \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

if [ $? -eq 0 ]; then
    print_message "✅ Channel '${CHANNEL_NAME}' created successfully on RAFT cluster"
else
    print_error "❌ Failed to create channel '${CHANNEL_NAME}'"
    exit 1
fi

print_message "Joining Org1 peer to channel..."
# Set environment for Org1
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer channel join -b network/${CHANNEL_NAME}.block

print_message "Joining Org2 peer to channel..."
# Set environment for Org2
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/peers/peer0.org2.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/users/Admin@org2.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org2.medimidi.com:9051 \
            cli peer channel join -b network/${CHANNEL_NAME}.block

print_message "Setting anchor peers for organizations..."

# Create anchor peer updates
print_message "Creating anchor peer update for Org1..."
configtxgen -profile MedicalChannel -outputAnchorPeersUpdate ./network/Org1MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg Org1MSP

print_message "Creating anchor peer update for Org2..."
configtxgen -profile MedicalChannel -outputAnchorPeersUpdate ./network/Org2MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg Org2MSP

# Update anchor peers
print_message "Updating Org1 anchor peer..."
docker exec -e CORE_PEER_LOCALMSPID=Org1MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/peers/peer0.org1.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org1.medimidi.com/users/Admin@org1.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org1.medimidi.com:7051 \
            cli peer channel update \
                -o ${ORDERER_ADDRESS} \
                -c ${CHANNEL_NAME} \
                -f /opt/gopath/src/github.com/hyperledger/fabric/peer/network/Org1MSPanchors.tx \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

print_message "Updating Org2 anchor peer..."
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/peers/peer0.org2.medimidi.com/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/org2.medimidi.com/users/Admin@org2.medimidi.com/msp \
            -e CORE_PEER_ADDRESS=peer0.org2.medimidi.com:9051 \
            cli peer channel update \
                -o ${ORDERER_ADDRESS} \
                -c ${CHANNEL_NAME} \
                -f /opt/gopath/src/github.com/hyperledger/fabric/peer/network/Org2MSPanchors.tx \
                --tls \
                --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/medimidi.com/orderers/orderer0.medimidi.com/msp/tlscacerts/tlsca.medimidi.com-cert.pem

echo
print_message "🎉 Channel '${CHANNEL_NAME}' setup completed successfully!"
print_message "✅ RAFT consensus cluster is active with 2 orderers"
print_message "✅ Both organizations joined the channel"
print_message "✅ Anchor peers configured"

echo
print_message "Channel Status:"
print_message "  - Channel Name: ${CHANNEL_NAME}"
print_message "  - Consensus: RAFT (2 orderers)"
print_message "  - Organizations: Org1MSP, Org2MSP"
print_message "  - Peers: peer0.org1.medimidi.com:7051, peer0.org2.medimidi.com:9051"

echo
print_message "Next step: Run './network/scripts/deploy-chaincode.sh' to deploy the medical diagnosis chaincode"
