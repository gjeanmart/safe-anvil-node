#!/bin/bash

set -e

echo "=========================================="
echo "Testing Safe Anvil Node Locally"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="safe-anvil-node"
TAG="test"
CONTAINER_NAME="safe-anvil-node-test"
RPC_PORT=8545
CHAIN_ID=1337
BLOCK_TIME=2  # Set block time to 2 seconds for testing

# Cleanup function to always remove container
cleanup() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo ""
        echo -e "${YELLOW}Cleaning up container...${NC}"
        docker stop ${CONTAINER_NAME} > /dev/null 2>&1 || true
        docker rm ${CONTAINER_NAME} > /dev/null 2>&1 || true
        echo -e "${GREEN}✓ Container stopped and removed${NC}"
    fi
}

# Register cleanup function to run on exit (success or failure)
trap cleanup EXIT

echo ""
echo -e "${YELLOW}Step 1: Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${TAG} .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
else
    echo -e "${RED}✗ Docker build failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Starting container...${NC}"
docker run -d \
    --name ${CONTAINER_NAME} \
    -p ${RPC_PORT}:${RPC_PORT} \
    -e CHAIN_ID=${CHAIN_ID} \
    -e BLOCK_TIME=${BLOCK_TIME} \
    ${IMAGE_NAME}:${TAG}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started (block time: ${BLOCK_TIME}s)${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Waiting for Anvil to be ready...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:${RPC_PORT} > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Anvil is responding${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}✗ Timeout waiting for Anvil${NC}"
        docker logs ${CONTAINER_NAME}
        exit 1
    fi
    
    echo -n "."
    sleep 2
done

echo ""
echo -e "${YELLOW}Step 4: Waiting for Safe contracts deployment...${NC}"
echo "This may take a moment with block time enabled..."

# Poll for deployment completion with timeout
MAX_WAIT=60  # Maximum wait time in seconds
ELAPSED=0
CHECK_INTERVAL=5

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker logs ${CONTAINER_NAME} 2>&1 | grep -q "SINGLETONS"; then
        echo -e "${GREEN}✓ Safe contracts deployed${NC}"
        echo ""
        echo "=========================================="
        echo "Deployed Contract Addresses:"
        echo "=========================================="
        docker logs ${CONTAINER_NAME} 2>&1 | grep -A 20 "SINGLETONS"
        DEPLOYMENT_SUCCESS=true
        break
    fi
    
    echo -n "."
    sleep $CHECK_INTERVAL
    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
done

if [ "${DEPLOYMENT_SUCCESS}" != "true" ]; then
    echo ""
    echo -e "${RED}✗ Safe contracts deployment not detected after ${MAX_WAIT}s${NC}"
    echo ""
    echo "Container logs (last 50 lines):"
    echo "=========================================="
    docker logs ${CONTAINER_NAME} 2>&1 | tail -50
    echo "=========================================="
    echo ""
    echo -e "${RED}Test failed: Deployment not completed in time${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 5: Testing RPC endpoint...${NC}"
BLOCK_NUMBER=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://localhost:${RPC_PORT} | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ ! -z "$BLOCK_NUMBER" ]; then
    echo -e "${GREEN}✓ RPC endpoint working. Current block: ${BLOCK_NUMBER}${NC}"
else
    echo -e "${RED}✗ RPC endpoint not responding correctly${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Test completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Test results:"
echo "  - RPC endpoint: http://localhost:${RPC_PORT}"
echo "  - Chain ID: ${CHAIN_ID}"
echo "  - Block time: ${BLOCK_TIME}s"
echo "  - Current block: ${BLOCK_NUMBER}"
echo ""
