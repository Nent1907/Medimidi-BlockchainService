#!/bin/bash
#
# Medical Diagnosis Blockchain Network Startup Script
# This script starts the Hyperledger Fabric network for the medical diagnosis system
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

echo -e "${BLUE}🏥 Medical Diagnosis Blockchain Network Startup${NC}"
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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# Cleanup any existing containers
print_message "Cleaning up existing containers..."
docker-compose down --volumes --remove-orphans 2>/dev/null || true

# Remove any dangling networks
docker network prune -f 2>/dev/null || true

# Create necessary directories
print_message "Creating necessary directories..."
mkdir -p network/organizations/fabric-ca/org1
mkdir -p network/organizations/fabric-ca/org2  
mkdir -p network/organizations/fabric-ca/orderer
mkdir -p network/organizations/peerOrganizations/org1.medimidi.com
mkdir -p network/organizations/peerOrganizations/org2.medimidi.com
mkdir -p network/organizations/ordererOrganizations/medimidi.com
mkdir -p logs
mkdir -p wallet

# Generate crypto material using cryptogen
print_message "Generating cryptographic material..."
if [ ! -d "network/organizations/peerOrganizations" ] || [ ! -d "network/organizations/ordererOrganizations" ]; then
    print_message "Running cryptogen to generate certificates..."
    ./network/scripts/generate-crypto.sh
    
    if [ $? -eq 0 ]; then
        print_message "✅ Cryptographic material generated successfully"
    else
        print_error "❌ Failed to generate cryptographic material"
        exit 1
    fi
else
    print_message "✅ Cryptographic material already exists"
fi

# Start the network
print_message "Starting Hyperledger Fabric network..."
if docker-compose up -d; then
    print_message "Network containers are starting up..."
else
    print_error "Failed to start network containers"
    exit 1
fi

# Wait for containers to be ready
print_message "Waiting for containers to be ready..."
sleep 30

# Check container status
print_message "Checking container status..."
docker-compose ps

# Test network connectivity
print_message "Testing network connectivity..."
HEALTHY_CONTAINERS=0
TOTAL_CONTAINERS=0

for container in ca.org1.medimidi.com ca.org2.medimidi.com ca.orderer.medimidi.com orderer0.medimidi.com orderer1.medimidi.com peer0.org1.medimidi.com peer0.org2.medimidi.com; do
    TOTAL_CONTAINERS=$((TOTAL_CONTAINERS + 1))
    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        print_message "✅ $container is running"
        HEALTHY_CONTAINERS=$((HEALTHY_CONTAINERS + 1))
    else
        print_warning "❌ $container is not running"
    fi
done

# Display results
echo
if [ $HEALTHY_CONTAINERS -eq $TOTAL_CONTAINERS ]; then
    print_message "🎉 All containers are running successfully!"
    print_message "Network is ready for use."
    echo
    print_message "Next steps:"
    echo "  1. Run './network/scripts/create-channel.sh' to create the channel"
    echo "  2. Run './network/scripts/deploy-chaincode.sh' to deploy the chaincode"
    echo "  3. Run 'cd api && npm install && npm start' to start the API server"
else
    print_warning "$HEALTHY_CONTAINERS out of $TOTAL_CONTAINERS containers are running"
    print_warning "Some containers may still be starting up. Check with 'docker-compose ps'"
fi

echo
print_message "Useful commands:"
echo "  - View logs: docker-compose logs -f [container-name]"
echo "  - Stop network: docker-compose down"
echo "  - Restart network: docker-compose restart"
echo "  - View running containers: docker-compose ps"

echo
print_message "🏥 Medical Diagnosis Blockchain Network startup completed!"
echo -e "${BLUE}=================================================${NC}"
