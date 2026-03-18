# 🔗 Blockchain Node Options

Bạn có thể chạy demo này với nhiều loại blockchain nodes khác nhau. Dưới đây là hướng dẫn chi tiết:

---

## 1️⃣ Anvil (Foundry) - ⭐ Recommended

**Ưu điểm:**
- ⚡ Cực nhanh
- 🚀 Instant mining
- 💰 Pre-funded accounts
- 🎯 Được thiết kế cho testing

**Cách dùng:**
```bash
# Start Anvil
anvil

# Deploy contracts (terminal khác)
forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Start UI
cd ui && python3 -m http.server 3000
```

**Default Config:**
- Port: `8545`
- Chain ID: `31337`
- Pre-funded accounts: 10 accounts with 10,000 ETH each

---

## 2️⃣ Geth (Go Ethereum) - Dev Mode

**Ưu điểm:**
- 🏛️ Official Ethereum implementation
- 🌐 Gần giống mainnet hơn
- 🔧 Advanced features

**Cách dùng:**

### Option A: Sử dụng script có sẵn

```bash
# Start Geth dev mode
./start-geth-dev.sh

# Trong terminal khác, deploy contracts
./deploy-to-geth.sh

# Start UI
cd ui && python3 -m http.server 3000
```

### Option B: Manual setup

```bash
# Start Geth
geth --dev \
  --http \
  --http.addr "0.0.0.0" \
  --http.port 8545 \
  --http.api "eth,net,web3,personal,miner" \
  --http.corsdomain "*" \
  --dev.period 0 \
  --allow-insecure-unlock \
  --datadir ./geth-data

# Deploy contracts
forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --unlocked
```

**Default Config:**
- Port: `8545`
- Chain ID: `1337` (dev mode)
- Coinbase account: Auto-funded

---

## 3️⃣ Hardhat Network

**Ưu điểm:**
- 📦 Phổ biến trong ecosystem
- 🔍 Built-in console.log trong Solidity
- 🐛 Great debugging features

**Setup:**

```bash
# Install Hardhat (nếu chưa có)
npm install --save-dev hardhat

# Create hardhat.config.js
cat > hardhat.config.js << EOF
require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      chainId: 31337
    }
  }
};
EOF

# Start Hardhat node
npx hardhat node

# Deploy contracts (terminal khác)
forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Default Config:**
- Port: `8545`
- Chain ID: `31337`
- Pre-funded accounts: 20 accounts

---

## 4️⃣ Ganache

**Ưu điểm:**
- 🖥️ GUI available
- 👀 Easy to visualize transactions
- 🎓 Good for beginners

**Cách dùng:**

### CLI:
```bash
# Install Ganache CLI
npm install -g ganache

# Start Ganache
ganache --port 8545 --chainId 31337

# Deploy contracts
forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key <GANACHE_PRIVATE_KEY>
```

### GUI:
1. Download Ganache GUI từ https://trufflesuite.com/ganache/
2. Start new workspace
3. Configure RPC server: `http://127.0.0.1:8545`
4. Deploy contracts như bình thường

---

## 5️⃣ Local Testnet (Besu, Nethermind, etc.)

**Ưu điểm:**
- 🔬 Testing với different client implementations
- 🏢 Enterprise features

**Note:** Setup phức tạp hơn, cần config files riêng.

---

## 🎯 So sánh nhanh:

| Feature | Anvil | Geth Dev | Hardhat | Ganache |
|---------|-------|----------|---------|---------|
| Speed | ⚡⚡⚡ | ⚡⚡ | ⚡⚡ | ⚡⚡ |
| Setup | Dễ | Trung bình | Dễ | Dễ |
| Like Mainnet | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| Debugging | Good | Advanced | Excellent | Good |
| GUI | ❌ | Console | ❌ | ✅ |

---

## 🔧 Troubleshooting

### Port đã được dùng:
```bash
# Check port 8545
lsof -i :8545

# Kill process
kill -9 <PID>
```

### Chain ID không khớp:
- Anvil: `31337`
- Geth dev: `1337`
- Hardhat: `31337`
- Update UI nếu cần

### Cannot connect:
```bash
# Test RPC connection
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545
```

---

## 🚀 Recommendation

Cho demo này, **Anvil là tốt nhất** vì:
1. ✅ Được build specifically cho Foundry
2. ✅ Cực nhanh
3. ✅ Zero config
4. ✅ Pre-funded accounts

Nhưng nếu bạn muốn test trong môi trường gần giống mainnet hơn, dùng **Geth dev mode**.

---

## 📚 Resources

- Anvil docs: https://book.getfoundry.sh/anvil/
- Geth docs: https://geth.ethereum.org/docs/getting-started/dev-mode
- Hardhat network: https://hardhat.org/hardhat-network/
- Ganache: https://trufflesuite.com/docs/ganache/

