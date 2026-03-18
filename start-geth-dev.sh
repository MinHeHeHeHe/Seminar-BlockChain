#!/bin/bash

# Start Geth in dev mode for testing
# This creates a local development blockchain similar to Anvil

echo "🚀 Starting Geth in dev mode..."

geth --dev \
  --http \
  --http.addr "0.0.0.0" \
  --http.port 8545 \
  --http.api "eth,net,web3,personal,miner" \
  --http.corsdomain "*" \
  --dev.period 0 \
  --allow-insecure-unlock \
  --datadir ./geth-data \
  console

# Flags explained:
# --dev: Enable developer mode with instant mining
# --http: Enable HTTP-RPC server
# --http.addr: HTTP-RPC server listening interface (0.0.0.0 = all interfaces)
# --http.port: HTTP-RPC server listening port
# --http.api: API's offered over the HTTP-RPC interface
# --http.corsdomain: Allow cross-origin requests from any domain
# --dev.period: Block mining interval (0 = instant)
# --allow-insecure-unlock: Allow account unlocking when HTTP is enabled
# --datadir: Data directory for the databases

