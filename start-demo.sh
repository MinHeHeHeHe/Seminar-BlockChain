#!/bin/bash

# DeFi Security Demo - Quick Start Script

echo "🔐 DeFi Security Demo - Starting..."
echo ""

# Check if anvil is running
if ! lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Anvil not running. Starting Anvil..."
    anvil > anvil.log 2>&1 &
    ANVIL_PID=$!
    echo "✅ Anvil started (PID: $ANVIL_PID)"
    sleep 2
else
    echo "✅ Anvil already running"
fi

# Check if UI server is running
if ! lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null ; then
    echo "🌐 Starting UI server..."
    cd ui
    python3 -m http.server 3000 > ../ui-server.log 2>&1 &
    UI_PID=$!
    cd ..
    echo "✅ UI server started (PID: $UI_PID)"
else
    echo "✅ UI server already running"
fi

echo ""
echo "🎉 All services running!"
echo ""
echo "📊 Web UI: http://localhost:3000"
echo "⛓️  Anvil RPC: http://localhost:8545"
echo ""
echo "📝 To deploy contracts:"
echo "   forge script script/SimpleDemo.s.sol:SimpleDemo --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""
echo "🛑 To stop all services:"
echo "   ./stop-demo.sh"
echo ""

