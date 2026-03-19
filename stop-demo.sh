#!/bin/bash

# Stop all demo services (Windows Git Bash friendly)

echo "🛑 Stopping DeFi Security Demo..."
echo ""

stop_port() {
    PORT=$1
    NAME=$2

    PID=$(netstat -ano 2>/dev/null | grep LISTENING | grep ":$PORT" | awk '{print $5}' | head -n 1)

    if [ -n "$PID" ]; then
        echo "Stopping $NAME on port $PORT..."
        taskkill //PID "$PID" //F >/dev/null 2>&1
        echo "✅ $NAME stopped (PID: $PID)"
    else
        echo "⚠️  $NAME not running"
    fi
}

# Stop Anvil
stop_port 8545 "Anvil"

# Stop UI server
stop_port 3000 "UI server"

# Clean up log files
if [ -f "anvil.log" ]; then
    rm -f anvil.log
    echo "🧹 Removed anvil.log"
fi

if [ -f "ui-server.log" ]; then
    rm -f ui-server.log
    echo "🧹 Removed ui-server.log"
fi

echo ""
echo "✅ All services stopped!"