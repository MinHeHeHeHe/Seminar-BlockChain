# DeFi Security Attack Visualizer

Interactive web UI to visualize and understand DeFi attack vectors.

## Features

-   📊 **Real-time Visualization**: See attacks happen in real-time
-   📈 **Charts & Graphs**: Visual representation of price manipulation
-   🎯 **Step-by-Step Flow**: Follow attack execution step by step
-   🔗 **Live Connection**: Connect to Anvil local node
-   📝 **Transaction Logs**: Monitor all transactions and state changes

## Quick Start

### 1. Start Anvil (if not running)

```bash
anvil
```

### 2. Deploy Contracts

In another terminal:

```bash
cd /Users/kenn/defi-security-demo
forge script script/SimpleDemo.s.sol:SimpleDemo --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 3. Start UI Server

```bash
cd ui
python3 -m http.server 3000
```

Or with Node.js:

```bash
cd ui
npx http-server -p 3000
```

### 4. Open Browser

Navigate to: `http://localhost:3000`

## Attack Demonstrations

### Oracle Manipulation Attack

1. **Initial State**: View DEX reserves and oracle price
2. **Flash Swap**: Borrow tokens to manipulate reserves
3. **Price Manipulation**: Oracle reads manipulated price
4. **Over-borrow**: Borrow more than collateral worth
5. **Profit**: Keep stolen funds

### Coming Soon

-   Governance Takeover Visualization
-   Vault Inflation Attack Visualization
-   Real-time transaction monitoring
-   Custom attack parameters

## Architecture

```
ui/
├── index.html          # Main HTML structure
├── style.css           # Styling and animations
├── app.js              # Web3 logic and visualizations
├── package.json        # Dependencies
└── README.md           # This file
```

## Technologies

-   **ethers.js**: Ethereum interactions
-   **Chart.js**: Price charts and visualizations
-   **Vanilla JS**: No framework dependencies
-   **CSS3**: Modern animations and transitions

## Development

The UI connects to your local Anvil instance and reads contract states to visualize attacks.

Key features:

-   Auto-detects deployed contracts from forge broadcast artifacts
-   Real-time state updates
-   Interactive step-by-step attack flow
-   Beautiful dark theme UI

## Troubleshooting

### Connection Failed

Make sure Anvil is running:

```bash
anvil
```

### No Deployed Contracts

Deploy contracts first:

```bash
forge script script/SimpleDemo.s.sol:SimpleDemo --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Port Already in Use

Use a different port:

```bash
python3 -m http.server 3001
```

## Educational Purpose

⚠️ **WARNING**: This tool is for educational purposes only. Never use on mainnet or with real funds!

## License

MIT
