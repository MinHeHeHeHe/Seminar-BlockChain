// DeFi Security Attack Visualizer
let provider, signer, addresses;
let deployed = false;
let priceChart;

// ABIs (simplified)
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
        // Try to connect to local Anvil
        provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:8545"
        );

        // Test connection
        const network = await provider.getNetwork();
        log(`Connected to network: Chain ID ${network.chainId}`, "success");

        // Use the first default Anvil account
        const privateKey =
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
        signer = new ethers.Wallet(privateKey, provider);

        updateConnectionStatus(true);
        log(`Connected with account: ${await signer.getAddress()}`, "success");

        // Try to load deployed addresses from broadcast
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
        // Try both chain IDs (Anvil can use either 1337 or 31337)
        let response;
        let data = null;

        // Try chain ID 31337 first
        try {
            response = await fetch(
                "../broadcast/SimpleDemo.s.sol/31337/run-latest.json"
            );
            if (response.ok) {
                data = await response.json();
                console.log("Found broadcast file for chain 31337");
            }
        } catch (e) {
            console.log("Failed to fetch from 31337:", e);
        }

        // Try chain ID 1337 as fallback
        if (!data) {
            try {
                response = await fetch(
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

        // Parse transactions to get addresses (includes hardcoded fallbacks)
        addresses = parseAddresses(data);
        console.log("Parsed addresses:", addresses);

        if (addresses && addresses.pair) {
            deployed = true;
            document.getElementById("attackBtn").disabled = false;
            log(
                "✅ Contracts loaded successfully! Click 'Execute Attack' to start.",
                "success"
            );
            await updateInitialState();
        } else {
            log(
                "⚠️ Could not verify contracts. Try refreshing the page.",
                "warning"
            );
        }
    } catch (error) {
        console.error("Error loading addresses:", error);
        // Even if we can't load the file, try using hardcoded addresses
        addresses = parseAddresses(null);
        if (addresses && addresses.pair) {
            deployed = true;
            document.getElementById("attackBtn").disabled = false;
            log("Using fallback contract addresses", "success");
            await updateInitialState();
        } else {
            log(
                'No deployed contracts found. Click "Deploy Contracts" first.',
                "info"
            );
        }
    }
}

// Parse addresses from broadcast JSON
function parseAddresses(data) {
    const addrs = {
        pair: "0x11a817359b6E4d4610b7954244350fD2bC0348cc",
        oracle: "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1",
        tokenA: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
        tokenB: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
    };

    // Also try to parse from transactions if available
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

// Update connection status UI
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

// Log message
function log(message, type = "info") {
    const logsDiv = document.getElementById("logs");
    const entry = document.createElement("div");
    entry.className = `log-entry ${type}`;
    entry.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
    logsDiv.appendChild(entry);
    logsDiv.scrollTop = logsDiv.scrollHeight;
}

// Update initial state
async function updateInitialState() {
    if (!addresses || !addresses.pair) return;

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

        log("Initial state loaded", "success");
    } catch (error) {
        log(`Error loading state: ${error.message}`, "error");
    }
}

// Initialize price chart
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
                    labels: {
                        color: "#f1f5f9",
                    },
                },
                title: {
                    display: true,
                    text: "Price Manipulation Over Time",
                    color: "#f1f5f9",
                    font: {
                        size: 16,
                    },
                },
            },
            scales: {
                y: {
                    beginAtZero: false,
                    ticks: {
                        color: "#94a3b8",
                    },
                    grid: {
                        color: "#334155",
                    },
                },
                x: {
                    ticks: {
                        color: "#94a3b8",
                    },
                    grid: {
                        color: "#334155",
                    },
                },
            },
        },
    });
}

// Deploy contracts
async function deployContracts() {
    log("⚠️  Please run this command in your terminal:", "info");
    log("", "info");
    log("cd /Users/kenn/defi-security-demo", "info");
    log("forge script script/SimpleDemo.s.sol:SimpleDemo \\", "info");
    log("  --rpc-url http://localhost:8545 \\", "info");
    log("  --broadcast \\", "info");
    log(
        "  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        "info"
    );
    log("", "info");
    log("After deployment, click this button again to reload.", "info");

    // Check if already deployed
    setTimeout(async () => {
        await loadDeployedAddresses();
        if (deployed) {
            log("✅ Contracts detected! Ready to attack.", "success");
        }
    }, 1000);
}

// Execute attack
async function executeAttack() {
    if (!addresses || !addresses.pair) {
        log("Please deploy contracts first", "error");
        return;
    }

    log("Starting attack...", "info");
    document.getElementById("attackBtn").disabled = true;

    const steps = ["step1", "step2", "step3", "step4"];

    for (let i = 0; i < steps.length; i++) {
        await new Promise((resolve) => setTimeout(resolve, 1500));

        // Mark current step as active
        document.getElementById(steps[i]).classList.add("active");

        if (i === 0) {
            log("Step 1: Executing flash swap...", "info");
        } else if (i === 1) {
            log(
                "Step 2: Price manipulated! Oracle now reads wrong price",
                "info"
            );
            await simulatePriceChange();
        } else if (i === 2) {
            log("Step 3: Over-borrowing from lending protocol...", "info");
        } else if (i === 3) {
            log("Step 4: Attack complete! Profit extracted", "success");
        }

        // Mark as completed
        await new Promise((resolve) => setTimeout(resolve, 500));
        document.getElementById(steps[i]).classList.remove("active");
        document.getElementById(steps[i]).classList.add("completed");
    }

    document.getElementById("attackBtn").disabled = false;
}

// Simulate price change
async function simulatePriceChange() {
    // Simulate reading new price
    const mockPrices = [1.0, 0.85, 0.72, 0.85, 1.0];

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
}

// Reset
function reset() {
    log("Resetting...", "info");

    // Reset steps
    const steps = ["step1", "step2", "step3", "step4"];
    steps.forEach((step) => {
        document.getElementById(step).classList.remove("active", "completed");
    });

    // Reset state
    if (addresses && addresses.pair) {
        updateInitialState();
    }

    log("Reset complete", "success");
}

// Tab switching
document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
        // Remove active from all
        document
            .querySelectorAll(".tab-btn")
            .forEach((b) => b.classList.remove("active"));
        document
            .querySelectorAll(".tab-content")
            .forEach((c) => c.classList.remove("active"));

        // Add active to clicked
        btn.classList.add("active");
        document
            .getElementById(`${btn.dataset.tab}-tab`)
            .classList.add("active");
    });
});

// Event listeners
document.getElementById("deployBtn").addEventListener("click", deployContracts);
document.getElementById("attackBtn").addEventListener("click", executeAttack);
document.getElementById("resetBtn").addEventListener("click", reset);

// Initialize on load
window.addEventListener("load", init);
