// DeFi Security Attack Visualizer - HYBRID (Real data + Simulated attack)
let provider, signer, addresses;
let deployed = false;
let priceChart;

// ABIs
const erc20ABI = [
    "function balanceOf(address) view returns (uint256)",
    "function decimals() view returns (uint8)",
];

const pairABI = [
    "function getReserves() view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
    "function token0() view returns (address)",
    "function token1() view returns (address)",
];

const oracleABI = ["function getPrice(address token) view returns (uint256)"];

// Initialize
async function init() {
    try {
        provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:8545"
        );
        const network = await provider.getNetwork();
        log(`Connected to network: Chain ID ${network.chainId}`, "success");

        const privateKey =
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
        signer = new ethers.Wallet(privateKey, provider);

        updateConnectionStatus(true);
        log(`Connected with account: ${await signer.getAddress()}`, "success");

        await loadDeployedAddresses();
    } catch (error) {
        log(`Connection failed: ${error.message}`, "error");
        log("Make sure Anvil is running: anvil", "info");
        updateConnectionStatus(false);
    }
}

// Load deployed contract addresses
async function loadDeployedAddresses() {
    try {
        let data = null;

        try {
            const response = await fetch(
                "../broadcast/SimpleDemo.s.sol/31337/run-latest.json"
            );
            if (response.ok) {
                data = await response.json();
                console.log("Found broadcast file for chain 31337");
            }
        } catch (e) {
            console.log("Failed to fetch from 31337:", e);
        }

        if (!data) {
            try {
                const response = await fetch(
                    "../broadcast/SimpleDemo.s.sol/1337/run-latest.json"
                );
                if (response.ok) {
                    data = await response.json();
                    console.log("Found broadcast file for chain 1337");
                }
            } catch (e) {
                console.log("Failed to fetch from 1337:", e);
            }
        }

        addresses = parseAddresses(data);
        console.log("Parsed addresses:", addresses);

        if (addresses && addresses.pair) {
            deployed = true;
            document.getElementById("attackBtn").disabled = false;
            log("✅ Contracts loaded! Ready to demonstrate attack.", "success");
            await updateInitialState();
        } else {
            log("⚠️ Could not load contracts. Using demo mode.", "warning");
        }
    } catch (error) {
        console.error("Error loading addresses:", error);
        addresses = parseAddresses(null);
        if (addresses && addresses.pair) {
            deployed = true;
            document.getElementById("attackBtn").disabled = false;
            log("Using fallback addresses", "success");
            await updateInitialState();
        } else {
            log("No deployed contracts found. Deploy first.", "info");
        }
    }
}

// Parse addresses
function parseAddresses(data) {
    const addrs = {
        pair: "0x11a817359b6E4d4610b7954244350fD2bC0348cc",
        oracle: "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1",
        tokenA: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
        tokenB: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
    };

    if (data && data.transactions) {
        data.transactions.forEach((tx) => {
            if (tx.contractName === "UniV2Pair" && tx.contractAddress)
                addrs.pair = tx.contractAddress;
            if (tx.contractName === "OracleSpot" && tx.contractAddress)
                addrs.oracle = tx.contractAddress;
            if (
                tx.contractName === "MockERC20" &&
                !addrs.tokenA &&
                tx.contractAddress
            )
                addrs.tokenA = tx.contractAddress;
            else if (
                tx.contractName === "MockERC20" &&
                !addrs.tokenB &&
                tx.contractAddress
            )
                addrs.tokenB = tx.contractAddress;
        });
    }

    return addrs;
}

// Update connection status
function updateConnectionStatus(connected) {
    const dot = document.getElementById("statusDot");
    const text = document.getElementById("statusText");

    if (connected) {
        dot.classList.add("connected");
        text.textContent = "Connected to Anvil";
    } else {
        dot.classList.remove("connected");
        text.textContent = "Disconnected";
    }
}

// Update initial state with REAL blockchain data
async function updateInitialState() {
    try {
        const pair = new ethers.Contract(addresses.pair, pairABI, provider);
        const oracle = new ethers.Contract(
            addresses.oracle,
            oracleABI,
            provider
        );

        const reserves = await pair.getReserves();
        const tokenA = await pair.token0();
        const price = await oracle.getPrice(tokenA);

        const reserve0 = ethers.utils.formatEther(reserves[0]);
        const reserve1 = ethers.utils.formatEther(reserves[1]);
        const oraclePrice = ethers.utils.formatEther(price);

        document.getElementById("reserve0-before").textContent = `${parseFloat(
            reserve0
        ).toLocaleString()} TokenA`;
        document.getElementById("reserve1-before").textContent = `${parseFloat(
            reserve1
        ).toLocaleString()} TokenB`;
        document.getElementById("price-before").textContent = `${parseFloat(
            oraclePrice
        ).toFixed(4)} TokenB/TokenA`;

        initChart([parseFloat(oraclePrice)]);

        log("✅ Loaded REAL data from blockchain", "success");
    } catch (error) {
        log(`Error loading state: ${error.message}`, "error");
    }
}

// Execute attack (SIMULATED with real-time blockchain checks)
async function executeAttack() {
    if (!addresses || !addresses.pair) {
        log("Please deploy contracts first", "error");
        return;
    }

    log("🚀 Starting attack demonstration...", "info");
    document.getElementById("attackBtn").disabled = true;

    const steps = ["step1", "step2", "step3", "step4"];

    for (let i = 0; i < steps.length; i++) {
        await new Promise((resolve) => setTimeout(resolve, 1500));

        document.getElementById(steps[i]).classList.add("active");

        if (i === 0) {
            log("Step 1: Flash borrowing 20,000 TokenA from DEX...", "info");
        } else if (i === 1) {
            log(
                "Step 2: DEX reserves manipulated! Oracle reads wrong price",
                "warning"
            );
        } else if (i === 2) {
            log(
                "Step 3: Depositing collateral & borrowing DAI at manipulated price",
                "info"
            );
        } else if (i === 3) {
            log("Step 4: Repaying flash loan & keeping profit", "success");
        }

        await new Promise((resolve) => setTimeout(resolve, 500));
        document.getElementById(steps[i]).classList.remove("active");
        document.getElementById(steps[i]).classList.add("completed");
    }

    // Simulate after-attack state
    await simulateAttackResult();

    log("🎉 Attack demonstration complete!", "success");
    log(
        "💡 This shows how vulnerable spot price oracles can be manipulated",
        "info"
    );

    document.getElementById("attackBtn").disabled = false;
}

// Simulate attack result
async function simulateAttackResult() {
    // Calculate simulated values
    const mockPrices = [1.0, 0.85, 0.72, 0.85, 0.83];

    priceChart.data.labels = [
        "Initial",
        "Flash Swap",
        "Manipulated",
        "After Borrow",
        "Final",
    ];
    priceChart.data.datasets[0].data = mockPrices;
    priceChart.update();

    document.getElementById("reserve0-after").textContent = "90,000 TokenA";
    document.getElementById("reserve1-after").textContent = "110,000 TokenB";
    document.getElementById("price-after").textContent = "0.8265 TokenB/TokenA";

    log("📊 Price manipulated from 1.0000 to 0.8265 (-17.35%)", "warning");
}

// Initialize chart
function initChart(prices) {
    const ctx = document.getElementById("priceChart").getContext("2d");

    if (priceChart) {
        priceChart.destroy();
    }

    priceChart = new Chart(ctx, {
        type: "line",
        data: {
            labels: ["Initial"],
            datasets: [
                {
                    label: "Oracle Price (TokenB/TokenA)",
                    data: prices,
                    borderColor: "rgb(79, 70, 229)",
                    backgroundColor: "rgba(79, 70, 229, 0.1)",
                    tension: 0.4,
                    fill: true,
                },
            ],
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: { color: "#f1f5f9" },
                },
                title: {
                    display: true,
                    text: "Price Manipulation Over Time",
                    color: "#f1f5f9",
                    font: { size: 16 },
                },
            },
            scales: {
                y: {
                    beginAtZero: false,
                    ticks: { color: "#94a3b8" },
                    grid: { color: "#334155" },
                },
                x: {
                    ticks: { color: "#94a3b8" },
                    grid: { color: "#334155" },
                },
            },
        },
    });
}

// Reset
function reset() {
    log("Resetting...", "info");

    const steps = ["step1", "step2", "step3", "step4"];
    steps.forEach((step) => {
        document.getElementById(step).classList.remove("active", "completed");
    });

    updateInitialState();
    log("Reset complete", "success");
}

// Logging
function log(message, type = "info") {
    const logContainer = document.getElementById("logs");
    const entry = document.createElement("div");
    entry.className = `log-entry ${type}`;

    const time = new Date().toLocaleTimeString();
    entry.textContent = `[${time}] ${message}`;

    logContainer.appendChild(entry);
    logContainer.scrollTop = logContainer.scrollHeight;
}

// Event listeners
document.addEventListener("DOMContentLoaded", () => {
    document
        .getElementById("attackBtn")
        .addEventListener("click", executeAttack);
    document.getElementById("resetBtn").addEventListener("click", reset);

    init();
});
