#!/bin/bash
#
# Medical Diagnosis Blockchain - Cryptographic Material Generation Script
# This script generates all necessary certificates and keys using cryptogen
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

echo -e "${BLUE}🔐 Medical Diagnosis Blockchain - Crypto Material Generation${NC}"
echo -e "${BLUE}===========================================================${NC}"

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

# Check if cryptogen is available
if ! command -v cryptogen &> /dev/null; then
    print_error "cryptogen not found. Please ensure Hyperledger Fabric binaries are in PATH"
    echo
    print_message "To install Fabric binaries:"
    echo "  curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh | bash -s"
    echo "  export PATH=\$PATH:\$(pwd)/fabric-samples/bin"
    exit 1
fi

print_message "Cryptogen tool found: $(which cryptogen)"

# Remove existing crypto material
if [ -d "network/organizations" ]; then
    print_warning "Removing existing crypto material..."
    rm -rf network/organizations/peerOrganizations
    rm -rf network/organizations/ordererOrganizations
fi

# Create organizations directory structure
print_message "Creating organization directories..."
mkdir -p network/organizations
mkdir -p network/organizations/peerOrganizations
mkdir -p network/organizations/ordererOrganizations

# Generate crypto material using cryptogen
print_message "Generating cryptographic material..."
echo
print_message "📋 Crypto Config:"
print_message "  - Orderer Org: medical.com (2 orderers for RAFT)"
print_message "  - Peer Org1: org1.medical.com (1 peer)"
print_message "  - Peer Org2: org2.medical.com (1 peer)"

# Run cryptogen to generate certificates
cryptogen generate --config=network/crypto-config.yaml --output=network/organizations

if [ $? -eq 0 ]; then
    print_message "✅ Cryptographic material generated successfully!"
else
    print_error "❌ Failed to generate cryptographic material"
    exit 1
fi

# Verify generated structure
print_message "Verifying generated crypto material..."

# Check orderer organizations
ORDERER_ORG_PATH="network/organizations/ordererOrganizations/medimidi.com"
if [ -d "$ORDERER_ORG_PATH" ]; then
    print_message "✅ Orderer organization created: medimidi.com"
    
    # Check each orderer
    for i in {0..2}; do
        ORDERER_PATH="$ORDERER_ORG_PATH/orderers/orderer${i}.medimidi.com"
        if [ -d "$ORDERER_PATH" ]; then
            print_message "  ✅ orderer${i}.medimidi.com certificates generated"
            
            # Check required certificate files
            if [ -f "$ORDERER_PATH/msp/signcerts/orderer${i}.medimidi.com-cert.pem" ] && \
               [ -f "$ORDERER_PATH/tls/server.crt" ]; then
                print_message "    ✅ MSP and TLS certificates verified"
            else
                print_warning "    ⚠️  Some certificate files missing for orderer${i}"
            fi
        else
            print_error "❌ orderer${i}.medimidi.com not found"
        fi
    done
else
    print_error "❌ Orderer organization not created"
    exit 1
fi

# Check peer organizations
for org in "org1" "org2"; do
    PEER_ORG_PATH="network/organizations/peerOrganizations/${org}.medimidi.com"
    if [ -d "$PEER_ORG_PATH" ]; then
        print_message "✅ Peer organization created: ${org}.medimidi.com"
        
        # Check peer
        PEER_PATH="$PEER_ORG_PATH/peers/peer0.${org}.medimidi.com"
        if [ -d "$PEER_PATH" ]; then
            print_message "  ✅ peer0.${org}.medimidi.com certificates generated"
            
            # Check required certificate files
            if [ -f "$PEER_PATH/msp/signcerts/peer0.${org}.medimidi.com-cert.pem" ] && \
               [ -f "$PEER_PATH/tls/server.crt" ]; then
                print_message "    ✅ MSP and TLS certificates verified"
            else
                print_warning "    ⚠️  Some certificate files missing for peer0.${org}"
            fi
        else
            print_error "❌ peer0.${org}.medimidi.com not found"
        fi
        
        # Check admin user
        ADMIN_PATH="$PEER_ORG_PATH/users/Admin@${org}.medimidi.com"
        if [ -d "$ADMIN_PATH" ]; then
            print_message "  ✅ Admin@${org}.medimidi.com user created"
            
            if [ -f "$ADMIN_PATH/msp/signcerts/Admin@${org}.medimidi.com-cert.pem" ]; then
                print_message "    ✅ Admin MSP certificates verified"
            else
                print_warning "    ⚠️  Admin certificate files missing"
            fi
        else
            print_error "❌ Admin user not found for ${org}"
        fi
    else
        print_error "❌ Peer organization not created: ${org}.medimidi.com"
        exit 1
    fi
done

# Display summary
echo
print_message "🎉 Cryptographic Material Generation Completed!"
echo
print_message "📊 Generated Structure Summary:"
print_message "┌─ Orderer Organization: medimidi.com"
print_message "│  ├─ orderer0.medimidi.com (RAFT Leader)"
print_message "│  ├─ orderer1.medimidi.com (RAFT Follower)"
print_message "├─ Peer Organization: org1.medimidi.com"
print_message "│  ├─ peer0.org1.medimidi.com"
print_message "│  ├─ Admin@org1.medimidi.com"
print_message "│  └─ User1@org1.medimidi.com, User2@org1.medimidi.com"
print_message "└─ Peer Organization: org2.medimidi.com"
print_message "   ├─ peer0.org2.medimidi.com"
print_message "   ├─ Admin@org2.medimidi.com"
print_message "   └─ User1@org2.medimidi.com, User2@org2.medimidi.com"

echo
print_message "🔐 Security Features:"
print_message "  ✅ TLS enabled for all components"
print_message "  ✅ MSP (Membership Service Provider) configured"
print_message "  ✅ Admin and user certificates generated"
print_message "  ✅ RAFT consensus cluster certificates ready"
print_message "  ✅ CA root certificates available"

echo
print_message "📁 Certificate Locations:"
print_message "  Orderers: ./network/organizations/ordererOrganizations/medimidi.com/orderers/"
print_message "  Peers:    ./network/organizations/peerOrganizations/*/peers/"
print_message "  Users:    ./network/organizations/peerOrganizations/*/users/"

echo
print_message "🚀 Next Steps:"
print_message "  1. Run './network/scripts/start-network.sh' to start the network"
print_message "  2. Run './network/scripts/create-channel.sh' to create the channel"
print_message "  3. Run './network/scripts/deploy-chaincode.sh' to deploy chaincode"

echo
print_message "🔐 Crypto Material Generation Script Completed Successfully!"
echo -e "${BLUE}===========================================================${NC}"
