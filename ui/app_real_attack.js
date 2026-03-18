// DeFi Security Attack Visualizer - REAL ON-CHAIN EXECUTION
let provider, signer, addresses;
let deployed = false;
let priceChart;
let attackerContract = null;
let transactionHashes = [];

// ABIs
const erc20ABI = [
    "function balanceOf(address) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function transfer(address to, uint256 amount) returns (bool)",
    "function approve(address spender, uint256 amount) returns (bool)",
];

const pairABI = [
    "function getReserves() view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
    "function token0() view returns (address)",
    "function token1() view returns (address)",
];

const oracleABI = ["function getPrice(address token) view returns (uint256)"];

const lendingABI = [
    "function getPosition(address user) view returns (uint256 collateral, uint256 borrowed, bool healthy)",
];

// Attacker contract ABI
const attackerABI = [
    "constructor(address _pair, address _lending, address _collateralToken, address _borrowToken)",
    "function attack(uint256 flashAmount, uint256 borrowAmount)",
    "function withdraw()",
    "event AttackInitiated(uint256 flashAmount)",
    "event PriceManipulated(uint256 reserveBefore0, uint256 reserveBefore1, uint256 reserveAfter0, uint256 reserveAfter1)",
    "event BorrowedFromLending(uint256 amount)",
    "event AttackCompleted(uint256 profit)",
];

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
        dai: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
        lending: "0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44",
    };

    if (data && data.transactions) {
        data.transactions.forEach((tx) => {
            if (tx.contractName === "UniV2Pair" && tx.contractAddress)
                addrs.pair = tx.contractAddress;
            if (tx.contractName === "OracleSpot" && tx.contractAddress)
                addrs.oracle = tx.contractAddress;
            if (tx.contractName === "LendingMock" && tx.contractAddress)
                addrs.lending = tx.contractAddress;
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

// Update initial state
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

        log("Initial state loaded from blockchain", "success");
    } catch (error) {
        log(`Error loading state: ${error.message}`, "error");
    }
}

// Execute REAL attack
async function executeAttack() {
    if (!addresses || !addresses.pair) {
        log("Please deploy contracts first", "error");
        return;
    }

    log("🚀 Starting REAL on-chain attack...", "info");
    document.getElementById("attackBtn").disabled = true;
    transactionHashes = [];

    try {
        // Step 1: Deploy attacker contract
        log("Step 1: Deploying attacker contract...", "info");
        document.getElementById("step1").classList.add("active");

        const bytecodeResponse = await fetch("Attacker_Oracle.bytecode.txt");
        const bytecode = await bytecodeResponse.text();

        const AttackerFactory = new ethers.ContractFactory(
            attackerABI,
            bytecode.trim(),
            signer
        );

        attackerContract = await AttackerFactory.deploy(
            addresses.pair,
            addresses.lending,
            addresses.tokenA,
            addresses.dai
        );
        await attackerContract.deployed();

        log(`✅ Attacker deployed at: ${attackerContract.address}`, "success");
        addTransactionProof(
            "Deploy Attacker",
            attackerContract.deployTransaction.hash
        );

        document.getElementById("step1").classList.remove("active");
        document.getElementById("step1").classList.add("completed");
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Step 2: Fund attacker with TokenA
        log("Step 2: Funding attacker with 10,000 TokenA...", "info");
        document.getElementById("step2").classList.add("active");

        const tokenA = new ethers.Contract(addresses.tokenA, erc20ABI, signer);
        const fundTx = await tokenA.transfer(
            attackerContract.address,
            ethers.utils.parseEther("10000")
        );
        await fundTx.wait();

        log("✅ Attacker funded", "success");
        addTransactionProof("Fund Attacker", fundTx.hash);

        document.getElementById("step2").classList.remove("active");
        document.getElementById("step2").classList.add("completed");
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Step 3: Execute attack
        log("Step 3: Executing flash swap attack...", "info");
        document.getElementById("step3").classList.add("active");

        const flashAmount = ethers.utils.parseEther("20000"); // Borrow 20k tokens
        const borrowAmount = ethers.utils.parseEther("15000"); // Try to borrow 15k DAI

        const attackTx = await attackerContract.attack(
            flashAmount,
            borrowAmount,
            {
                gasLimit: 500000,
            }
        );

        log("⏳ Waiting for attack transaction...", "info");
        const receipt = await attackTx.wait();

        log("✅ Attack transaction mined!", "success");
        addTransactionProof("Execute Attack", attackTx.hash);

        // Parse events
        receipt.logs.forEach((log) => {
            try {
                const parsed = attackerContract.interface.parseLog(log);
                if (parsed.name === "AttackCompleted") {
                    const profit = ethers.utils.formatEther(parsed.args.profit);
                    addTransactionProof("Profit", `${profit} DAI`);
                }
            } catch (e) {}
        });

        document.getElementById("step3").classList.remove("active");
        document.getElementById("step3").classList.add("completed");
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Step 4: Verify results
        log("Step 4: Verifying attack results...", "info");
        document.getElementById("step4").classList.add("active");

        await updateAfterAttackState();

        document.getElementById("step4").classList.remove("active");
        document.getElementById("step4").classList.add("completed");

        log("🎉 Attack completed! Check transaction proofs below.", "success");
    } catch (error) {
        log(`❌ Attack failed: ${error.message}`, "error");
        console.error("Full error:", error);
    } finally {
        document.getElementById("attackBtn").disabled = false;
    }
}

// Update after-attack state
async function updateAfterAttackState() {
    try {
        const pair = new ethers.Contract(addresses.pair, pairABI, provider);
        const oracle = new ethers.Contract(
            addresses.oracle,
            oracleABI,
            provider
        );
        const dai = new ethers.Contract(addresses.dai, erc20ABI, provider);

        // Get new reserves
        const reserves = await pair.getReserves();
        const tokenA = await pair.token0();
        const price = await oracle.getPrice(tokenA);

        const reserve0 = ethers.utils.formatEther(reserves[0]);
        const reserve1 = ethers.utils.formatEther(reserves[1]);
        const oraclePrice = ethers.utils.formatEther(price);

        document.getElementById("reserve0-after").textContent = `${parseFloat(
            reserve0
        ).toLocaleString()} TokenA`;
        document.getElementById("reserve1-after").textContent = `${parseFloat(
            reserve1
        ).toLocaleString()} TokenB`;
        document.getElementById("price-after").textContent = `${parseFloat(
            oraclePrice
        ).toFixed(4)} TokenB/TokenA`;

        // Get attacker's DAI balance (profit)
        if (attackerContract) {
            const profit = await dai.balanceOf(attackerContract.address);
            const profitFormatted = ethers.utils.formatEther(profit);
            log(`💰 Attacker profit: ${profitFormatted} DAI`, "success");

            // Update chart
            updateChart(parseFloat(oraclePrice));
        }

        log("✅ Post-attack state verified on-chain", "success");
    } catch (error) {
        log(`Error updating state: ${error.message}`, "error");
    }
}

// Add transaction proof to UI
function addTransactionProof(label, value) {
    transactionHashes.push({ label, value });

    // Create proof element
    const proofContainer = document.getElementById("transactionProofs");
    if (!proofContainer) {
        const newContainer = document.createElement("div");
        newContainer.id = "transactionProofs";
        newContainer.className = "proof-container";
        newContainer.innerHTML = "<h3>📜 Transaction Proofs</h3>";
        document.querySelector(".visualization").appendChild(newContainer);
    }

    const proofElement = document.createElement("div");
    proofElement.className = "proof-item";
    proofElement.innerHTML = `
        <strong>${label}:</strong>
        <span class="hash">${value}</span>
        ${
            value.startsWith("0x")
                ? `<a href="https://etherscan.io/tx/${value}" target="_blank">View</a>`
                : ""
        }
    `;

    document.getElementById("transactionProofs").appendChild(proofElement);
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

// Update chart
function updateChart(newPrice) {
    if (priceChart) {
        priceChart.data.labels.push("After Attack");
        priceChart.data.datasets[0].data.push(newPrice);
        priceChart.update();
    }
}

// Reset
function reset() {
    log("Resetting...", "info");

    const steps = ["step1", "step2", "step3", "step4"];
    steps.forEach((step) => {
        document.getElementById(step).classList.remove("active", "completed");
    });

    transactionHashes = [];
    const proofContainer = document.getElementById("transactionProofs");
    if (proofContainer) {
        proofContainer.remove();
    }

    updateInitialState();
    log("Reset complete", "success");
}

// Logging
function log(message, type = "info") {
    const console = document.getElementById("console");
    const entry = document.createElement("div");
    entry.className = `log-entry ${type}`;

    const time = new Date().toLocaleTimeString();
    entry.textContent = `[${time}] ${message}`;

    console.appendChild(entry);
    console.scrollTop = console.scrollHeight;
}

// Event listeners
document.addEventListener("DOMContentLoaded", () => {
    document
        .getElementById("attackBtn")
        .addEventListener("click", executeAttack);
    document.getElementById("resetBtn").addEventListener("click", reset);

    init();
});
