#!/bin/bash

# Deploy contracts to Geth dev node
# Make sure Geth is running first: ./start-geth-dev.sh

echo "📝 Deploying to Geth dev node..."

# In Geth dev mode, the coinbase account is automatically funded
# We can use it directly

forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --unlocked \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

echo ""
echo "✅ Deployment complete!"
echo "📍 Check broadcast/ folder for contract addresses"

