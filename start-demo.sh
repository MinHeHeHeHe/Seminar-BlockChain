#!/bin/bash

# DeFi Security Demo - Quick Start Script (Windows Git Bash friendly)

echo "🔐 DeFi Security Demo - Starting..."
echo ""

is_port_listening() {
    netstat -ano 2>/dev/null | grep -q ":$1 "
}

# Check if anvil is running
if ! is_port_listening 8545; then
    echo "⚠️  Anvil not running. Starting Anvil..."
    anvil > anvil.log 2>&1 &
    ANVIL_PID=$!
    sleep 3

    if is_port_listening 8545; then
        echo "✅ Anvil started (PID: $ANVIL_PID)"
    else
        echo "❌ Failed to start Anvil. Check anvil.log"
        exit 1
    fi
else
    echo "✅ Anvil already running"
fi

# Detect Python command
PYTHON_CMD=""
if command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
else
    echo "❌ Python not found. Please install Python or add it to PATH."
    exit 1
fi

# Check if UI server is running
if ! is_port_listening 3000; then
    echo "🌐 Starting UI server..."
    cd ui || exit 1
    $PYTHON_CMD -m http.server 3000 > ../ui-server.log 2>&1 &
    UI_PID=$!
    cd .. || exit 1
    sleep 2

    if is_port_listening 3000; then
        echo "✅ UI server started (PID: $UI_PID)"
    else
        echo "❌ Failed to start UI server. Check ui-server.log"
        exit 1
    fi
else
    echo "✅ UI server already running"
fi

echo ""
echo "🎉 All services running!"
echo ""
echo "📊 Web UI: http://127.0.0.1:3000"
echo "⛓️  Anvil RPC: http://127.0.0.1:8545"
echo ""
echo "📝 To deploy contracts:"
echo "   forge script script/SimpleDemo.s.sol:SimpleDemo --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""
echo "🛑 To stop all services:"
echo "   ./stop-demo.sh"
echo ""