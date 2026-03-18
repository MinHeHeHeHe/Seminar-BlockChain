#!/bin/bash

# Stop all demo services

echo "🛑 Stopping DeFi Security Demo..."
echo ""

# Stop Anvil
if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null ; then
    echo "Stopping Anvil..."
    pkill -f anvil
    echo "✅ Anvil stopped"
else
    echo "⚠️  Anvil not running"
fi

# Stop UI server
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null ; then
    echo "Stopping UI server..."
    lsof -ti:3000 | xargs kill -9
    echo "✅ UI server stopped"
else
    echo "⚠️  UI server not running"
fi

# Clean up log files
if [ -f "anvil.log" ]; then
    rm anvil.log
fi

if [ -f "ui-server.log" ]; then
    rm ui-server.log
fi

echo ""
echo "✅ All services stopped!"

