# 🎨 Web UI Demo - Quick Start

## ⚡ Cách Nhanh Nhất (1 lệnh)

```bash
./start-demo.sh
```

Mở browser: **http://localhost:3000**

## 📖 Hướng Dẫn Chi Tiết

### Bước 1: Start Services

```bash
./start-demo.sh
```

Script này sẽ tự động:

-   ✅ Start Anvil (nếu chưa chạy)
-   ✅ Start UI server trên port 3000
-   ✅ Hiển thị tất cả URLs cần thiết

### Bước 2: Mở Web UI

Mở browser và truy cập:

```
http://localhost:3000
```

### Bước 3: Deploy Contracts

Trong UI, click nút **"Deploy Contracts"** hoặc chạy lệnh:

```bash
forge script script/SimpleDemo.s.sol:SimpleDemo \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Bước 4: Xem Attack Demo

1. Click tab **"Oracle Attack"**
2. Xem **Initial State** (reserves, price)
3. Click **"Execute Attack"**
4. Xem animation từng bước attack
5. Theo dõi **price chart** thay đổi
6. Đọc **transaction logs**

## 🎯 UI Features

### 📊 Oracle Manipulation Attack

-   **Real-time State Display**

    -   DEX reserves before/after
    -   Oracle price changes
    -   Interactive price chart

-   **Step-by-Step Visualization**

    -   Step 1: Flash Swap
    -   Step 2: Price Manipulation
    -   Step 3: Over-borrow
    -   Step 4: Profit

-   **Interactive Controls**
    -   Deploy contracts
    -   Execute attack
    -   Reset demo
    -   View transaction logs

### 🎨 Visual Elements

-   📈 **Price Chart**: Real-time price manipulation visualization
-   🔄 **Flow Diagram**: Step-by-step attack flow with animations
-   📝 **Transaction Logs**: Color-coded logs (success/error/info)
-   💹 **State Comparison**: Before/after attack metrics
-   🎯 **Active Step Highlighting**: Current step glows

### 🏛️ Coming Soon

-   Governance Attack Visualization
-   Vault Attack Visualization
-   Custom attack parameters
-   More interactive features

## 🛑 Stop Services

```bash
./stop-demo.sh
```

## 📱 Screenshots

### Main Dashboard

-   Dark theme với gradient header
-   Tab navigation (Oracle/Governance/Vault)
-   Connection status indicator

### Oracle Attack View

-   Initial vs After state cards
-   Live price chart
-   Step-by-step flow with animations
-   Action buttons (Deploy/Attack/Reset)
-   Real-time transaction logs

## 🔧 Troubleshooting

### Port 3000 đã được sử dụng

```bash
# Stop UI server
lsof -ti:3000 | xargs kill -9

# Hoặc dùng port khác
cd ui && python3 -m http.server 3001
```

### Anvil không kết nối được

```bash
# Check Anvil đang chạy
lsof -i :8545

# Start lại Anvil
pkill anvil
anvil
```

### UI không load contracts

1. Make sure Anvil đang chạy
2. Deploy contracts trước
3. Refresh page

## 💡 Tips

1. **Mở DevTools** (F12) để xem console logs
2. **Click Reset** sau mỗi attack để chạy lại
3. **Xem chart** để thấy rõ price manipulation
4. **Đọc logs** để hiểu flow chi tiết
5. **Hover cards** để xem hover effects

## 🎓 Learning Path

1. **Xem Initial State**: Hiểu về reserves và oracle price
2. **Chạy Attack**: Xem từng step và price changes
3. **Đọc Code**: Xem `app.js` để hiểu logic
4. **Đọc Contracts**: Xem source code trong `src/`
5. **Run Tests**: `forge test -vvvv` để xem chi tiết hơn

## 📚 Resources

-   **UI Code**: `ui/index.html`, `ui/style.css`, `ui/app.js`
-   **Contracts**: `src/` directory
-   **Tests**: `test/` directory
-   **Tutorial**: `TUTORIAL.md`
-   **Quick Start**: `QUICKSTART.md`

## 🌟 Features Highlight

### Animations

-   Smooth transitions between states
-   Step highlighting during attack
-   Chart updates with animation
-   Loading states

### Dark Theme

-   Eye-friendly colors
-   Gradient accents
-   Hover effects
-   Responsive design

### Interactivity

-   Click steps to see details
-   Hover for tooltips
-   Real-time updates
-   Responsive buttons

## 🚀 Advanced Usage

### Connect với Custom RPC

Edit `ui/app.js`:

```javascript
provider = new ethers.providers.JsonRpcProvider("YOUR_RPC_URL");
```

### Thêm Custom Attacks

1. Tạo tab mới trong HTML
2. Thêm logic trong `app.js`
3. Style trong `style.css`

### Export Data

UI logs có thể được copied từ console hoặc logs section.

---

**Happy Learning! 🎉**

⚠️ Educational purposes only. Do not use on mainnet!
