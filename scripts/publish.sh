#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if version argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version argument required${NC}"
    echo "Usage: ./publish.sh <version>"
    echo "Example: ./publish.sh v1.0.0"
    exit 1
fi

VERSION=$1
IMAGE_NAME="gjeanmart/safe-anvil-node"

# Validate version format (should start with 'v' followed by semantic version)
if ! [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${YELLOW}Warning: Version format should be vX.Y.Z (e.g., v1.0.0)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "=========================================="
echo "Publishing Safe Anvil Node to Docker Hub"
echo "=========================================="
echo -e "${BLUE}Version: ${VERSION}${NC}"
echo -e "${BLUE}Image: ${IMAGE_NAME}${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Check if user is logged in to Docker Hub
echo -e "${YELLOW}Step 1: Checking Docker Hub authentication...${NC}"
if ! docker info 2>&1 | grep -q "Username:"; then
    echo -e "${YELLOW}Not logged in to Docker Hub. Please login:${NC}"
    docker login
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Docker Hub login failed${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Authenticated${NC}"

# Create and use buildx builder
echo ""
echo -e "${YELLOW}Step 2: Setting up Docker buildx...${NC}"
if ! docker buildx inspect safe-builder > /dev/null 2>&1; then
    docker buildx create --name safe-builder --use
else
    docker buildx use safe-builder
fi
docker buildx inspect --bootstrap
echo -e "${GREEN}✓ Buildx ready${NC}"

# Build and push multi-platform image
echo ""
echo -e "${YELLOW}Step 3: Building and pushing multi-platform images...${NC}"
echo "This may take several minutes..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t ${IMAGE_NAME}:${VERSION} \
    -t ${IMAGE_NAME}:latest \
    --push \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Images built and pushed successfully${NC}"
else
    echo -e "${RED}✗ Build/push failed${NC}"
    exit 1
fi

# Update VERSION file
echo ""
echo -e "${YELLOW}Step 4: Updating VERSION file...${NC}"
echo ${VERSION#v} > VERSION
echo -e "${GREEN}✓ VERSION file updated${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}Publishing completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Published images:"
echo "  - ${IMAGE_NAME}:${VERSION}"
echo "  - ${IMAGE_NAME}:latest"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify on Docker Hub: https://hub.docker.com/r/gjeanmart/safe-anvil-node"
echo "  2. Tag git: git tag ${VERSION} && git push origin ${VERSION}"
echo "  3. Commit VERSION file: git add VERSION && git commit -m 'Release ${VERSION}'"
echo ""
