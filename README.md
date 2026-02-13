## Safe x Anvil x Hardhat Docker container

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/gjeanmart/safe-anvil-node)

A Docker container for launching a local Ethereum node using Anvil (Foundry) and deploying Safe's singleton contracts deterministically. This ensures contracts remain deployed across node restarts without requiring redeployment.

## Getting started

### Quick Start with Docker

```shell
docker run --name safe-anvil-node --rm \
  -p 8545:8545 \
  -e CHAIN_ID=1337 \
  -e BLOCK_TIME=5 \
  gjeanmart/safe-anvil-node:latest
```

### Docker Compose

```yaml
node:
  image: gjeanmart/safe-anvil-node:latest
  ports:
    - 8545:8545
  environment:
    MNEMONIC: ${MNEMONIC}
    CHAIN_ID: ${CHAIN_ID}
    BLOCK_TIME: 2  # Optional: mine blocks every 2 seconds
  volumes:
    - ./data/anvil:/db
  healthcheck:
    test: curl -sf -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' localhost:8545
    interval: 5s
    timeout: 5s
    retries: 5
```

## Environment Variables

| ENV_VAR          | default value                                               | description                                                               |
| ---------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------- |
| DB               | /db                                                         | Path to the directory where the chain database is stored                  |
| MNEMONIC         | test test test test test test test test test test test junk | HD wallet mnemonic for generating initial addresses                       |
| RPC_PORT         | 8545                                                        | Port for the RPC server                                                   |
| CHAIN_ID         | 1337                                                        | Chain ID of the network                                                   |
| BLOCK_TIME       |                                                             | Block time in seconds (if not set, mines blocks instantly on transaction) |
| ANVIL_EXTRA_ARGS |                                                             | Additional arguments for the Anvil command                                |

## Development

### Prerequisites

- Docker and Docker Compose
- Node.js and Yarn (for local development)
- Bash shell (for running scripts)

### Setup

Install dependencies:

```shell
yarn install
```

### Testing Locally

Test the Docker container locally before publishing:

```shell
yarn test:docker
```

This script will:

1. Build the Docker image
2. Start a container with `BLOCK_TIME=2` (blocks mined every 2 seconds)
3. Wait for Anvil to be ready
4. Verify Safe contracts deployment (waits longer due to block time)
5. Test RPC endpoint
6. Display deployed contract addresses
7. Automatically stop and remove the test container

**Note:** The test script uses a 2-second block time to verify that the deployment works correctly with block time enabled. This ensures compatibility with production-like environments.

### Building Locally

Build the Docker image locally:

```shell
yarn build:docker
```

### Running with Docker Compose

For local development with persistent data:

```shell
docker compose up
```

## Publishing

### Versioning

This project uses semantic versioning (vX.Y.Z format):

- **Major version (X)**: Breaking changes
- **Minor version (Y)**: New features, backwards compatible
- **Patch version (Z)**: Bug fixes, backwards compatible

Current version is tracked in the `VERSION` file.

### Publishing to Docker Hub

1. **Test locally** to ensure everything works:

   ```shell
   yarn test:docker
   ```

2. **Build and publish** to Docker Hub:

   ```shell
   yarn publish:docker v1.0.0
   ```

   This script will:
   - Verify Docker Hub authentication (prompts login if needed)
   - Build multi-platform images (linux/amd64, linux/arm64)
   - Push to Docker Hub with version tag and `latest` tag
   - Update the `VERSION` file

3. **Tag the git repository**:

   ```shell
   git add VERSION
   git commit -m "Release v1.0.0"
   git tag v1.0.0
   git push origin main
   git push origin v1.0.0
   ```

4. **Verify** the image on [Docker Hub](https://hub.docker.com/r/gjeanmart/safe-anvil-node)

### Release Checklist

- [ ] Make and commit all changes
- [ ] Run `yarn test:docker` to verify locally
- [ ] Run `yarn publish:docker vX.Y.Z` to build and publish
- [ ] Verify image on Docker Hub
- [ ] Commit VERSION file changes
- [ ] Tag git repository with matching version
- [ ] Push tags to GitHub

## Scripts

All scripts are located in the `scripts/` directory:

- **test-local.sh** - Build and test the Docker container locally with block time enabled
- **publish.sh** - Build multi-platform images and publish to Docker Hub

## Safe Singleton Contracts

The container automatically deploys the following Safe singleton contracts:

- Safe Mastercopy (L2)
- Safe Proxy Factory
- Multi Send
- Multi Send Call Only
- Fallback Handler
- Sign Message Lib
- Create Call
- Simulate Tx Accessor

All contracts are deployed deterministically at the same addresses across restarts.

## License

MIT
