# 🔥 Quick Fix - UI Không Bấm Được Attack

## Vấn Đề

-   UI không load được contracts
-   Button "Execute Attack" bị disable
-   Log: "No deployed contracts found"

## ✅ Solution (3 Bước)

### 1. Start Anvil (Terminal 1)

```bash
# Stop tất cả process đang dùng port 8545
lsof -ti:8545 | xargs kill -9

# Start Anvil
anvil
```

**Để Anvil chạy!** Không close terminal này.

### 2. Deploy Contracts (Terminal 2 - Terminal mới)

```bash
cd /Users/kenn/defi-security-demo

forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Chờ đến khi thấy** "=== DEMO COMPLETE ===" và không có lỗi.

### 3. Refresh UI

1. **Mở browser**: http://localhost:3000
2. **Refresh page** (F5 hoặc Cmd+R)
3. **Click "Deploy Contracts"** button để reload addresses
4. **Xem logs** - nên thấy "Contracts detected! Ready to attack"
5. **Click "Execute Attack"** button - giờ nên work!

## 🎯 Verify Đã OK

Trong UI logs, bạn sẽ thấy:

```
✅ Connected to network: Chain ID 1337
✅ Connected with account: 0xf39Fd6e51...
✅ Loaded deployed contracts
✅ Initial state loaded
```

Button "Execute Attack" sẽ màu đỏ và clickable.

## 🐛 Nếu Vẫn Không Work

### Check 1: Anvil đang chạy?

```bash
lsof -i :8545
```

Phải thấy `anvil` (KHÔNG phải geth hoặc process khác).

### Check 2: UI Server đang chạy?

```bash
lsof -i :3000
```

Phải thấy Python HTTP server.

Nếu không:

```bash
cd /Users/kenn/defi-security-demo/ui
python3 -m http.server 3000
```

### Check 3: Contracts đã deploy?

```bash
ls -la /Users/kenn/defi-security-demo/broadcast/SimpleDemo.s.sol/1337/
```

Phải thấy file `run-latest.json`.

### Check 4: Xem Console Logs

1. Mở DevTools (F12 or Cmd+Option+I)
2. Click tab "Console"
3. Xem có error gì không
4. Share với tôi nếu cần

## 🚀 Full Reset (Nuclear Option)

Nếu mọi thứ đều không work:

```bash
# Stop tất cả
pkill anvil
lsof -ti:3000 | xargs kill -9

# Clean broadcast
rm -rf broadcast/ cache/

# Start lại tất cả

# Terminal 1: Anvil
anvil

# Terminal 2: Deploy
cd /Users/kenn/defi-security-demo
forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Terminal 3: UI
cd /Users/kenn/defi-security-demo/ui
python3 -m http.server 3000
```

Sau đó mở browser: http://localhost:3000

## 💡 Tips

1. **Luôn giữ Anvil chạy** trong một terminal riêng
2. **Refresh UI** sau mỗi lần deploy mới
3. **Xem logs trong UI** để debug
4. **Check DevTools Console** nếu có vấn đề

## 📹 Expected Flow

1. Anvil chạy → Thấy "Listening on 127.0.0.1:8545"
2. Deploy → Thấy contract addresses
3. UI Refresh → Logs show "Connected" và "Loaded contracts"
4. Click Attack → See animation và price changes!

---

**Nếu vẫn không work, share cho tôi:**

-   Screenshot UI logs
-   Console errors (F12)
-   Terminal output khi deploy
