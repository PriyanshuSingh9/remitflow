#!/bin/bash

# ==========================================
# RemitFlow Local Development Environment
# ==========================================

cleanup() {
    echo ""
    echo "🛑 Stopping local services..."
    # Gracefully try to kill the immediate child jobs
    kill $(jobs -p) 2>/dev/null
    
    # FORCE TERMINATE any process holding our allocated ports 
    fuser -k 8787/tcp 2>/dev/null  # Backend API
    fuser -k 8545/tcp 2>/dev/null  # Anvil Node
    
    echo "✅ Cleaned up successfully."
    exit
}

trap cleanup SIGINT SIGTERM

echo "🚀 Starting RemitFlow Local Environment..."
echo ""

# 1. Start Anvil Local Blockchain
echo "🔗 Starting Anvil blockchain node..."
if command -v anvil &> /dev/null; then
    if [ -f "anvil-state.json" ]; then
        anvil --load-state anvil-state.json --host 127.0.0.1 --port 8545 > /dev/null 2>&1 &
        echo "   ✅ Anvil running on http://localhost:8545 (loaded from state)"
    else
        anvil --host 127.0.0.1 --port 8545 > /dev/null 2>&1 &
        echo "   ✅ Anvil running on http://localhost:8545"
    fi
else
    echo "   ⚠️ Anvil not found. Make sure Foundry is installed."
fi

# 2. Start Backend API
echo "📂 Starting Backend API..."
cd backend || exit
if [ -d "node_modules" ]; then
    npm run dev:watch > /dev/null 2>&1 &
    echo "   ✅ Backend starting on http://localhost:8787"
else
    echo "   ⚠️ Missing node_modules in backend! Please run 'npm install' in the backend directory."
    cleanup
fi
cd .. || exit

# 3. Setup ADB Reverse Tunneling
echo "🌉 Setting up ADB reverse tunneling for Android devices..."
if command -v adb &> /dev/null; then
    adb reverse tcp:8787 tcp:8787 2>/dev/null
    adb reverse tcp:8545 tcp:8545 2>/dev/null
    echo "   ✅ Port 8787 (Backend) and 8545 (Anvil) forwarded to Android device"
else
    echo "   ℹ️ adb not found in PATH, skipping reverse tunneling"
fi

echo ""
echo "✅ All background services successfully launched!"
echo "   - Backend API:  http://localhost:8787"
echo "   - Anvil Node:   http://localhost:8545"
echo ""
echo "📱 Launching Flutter Mobile App in the foreground..."
echo "💡 Press 'q' to quit Flutter, or Ctrl+C to shut down everything."
echo ""

# 4. Start Mobile App in foreground to preserve interactive hot-reload (r, R, q)
cd mobile || exit
flutter run

# Wait for background processes if flutter run exits
wait
