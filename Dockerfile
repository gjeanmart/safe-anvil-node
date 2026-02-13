FROM node:20.3.0

WORKDIR /usr/src/app

# Install Foundry (for Anvil)
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="/root/.foundry/bin:${PATH}"
RUN foundryup

COPY . /usr/src/app
COPY ./entrypoint.sh /usr/local/bin

RUN yarn install --non-interactive --frozen-lockfile

# Create artifacts directory for Hardhat
RUN mkdir -p /usr/src/app/artifacts

# ENVIRONMENT VARIABLES with default values
ENV DB="/db"
ENV MNEMONIC="test test test test test test test test test test test junk"
ENV RPC_PORT=8545
ENV CHAIN_ID=1337
ENV BLOCK_TIME=""
ENV DETERMINISTIC_DEPLOYMENT="true"
ENV ANVIL_EXTRA_ARGS=""

# RUN
ENTRYPOINT ["/bin/sh", "/usr/local/bin/entrypoint.sh"]