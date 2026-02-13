#!/bin/sh

# Change to the correct directory
cd /usr/src/app;

# Build block time argument if BLOCK_TIME is set
BLOCK_TIME_ARG=""
if [ -n "$BLOCK_TIME" ]; then
    BLOCK_TIME_ARG="--block-time $BLOCK_TIME"
fi

# Start Anvil as a background process
anvil \
    --balance 1000  \
    --state $DB \
    --host 0.0.0.0 \
    --port $RPC_PORT \
    --mnemonic "$MNEMONIC" \
    --chain-id $CHAIN_ID \
    --code-size-limit 999999999 \
    $BLOCK_TIME_ARG \
    $ANVIL_EXTRA_ARGS &

# Wait for anvil node to initialize and then deploy contracts
npx wait-on tcp:$RPC_PORT && npx hardhat --network localhost deploy;

# The anvil node process never completes
# Waiting prevents the container from pausing
wait $!