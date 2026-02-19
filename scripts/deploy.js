const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    // Deploy Mock Tokens
    console.log("\n=== Deploying Mock Tokens ===");
    const MockDAI = await ethers.getContractFactory("MockDAI");
    const mockDAI = await MockDAI.deploy();
    await mockDAI.waitForDeployment();
    console.log("MockDAI deployed to:", mockDAI.target);

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    const mockUSDC = await MockUSDC.deploy();
    await mockUSDC.waitForDeployment();
    console.log("MockUSDC deployed to:", mockUSDC.target);

    const MockWETH = await ethers.getContractFactory("MockWETH");
    const mockWETH = await MockWETH.deploy();
    await mockWETH.waitForDeployment();
    console.log("MockWETH deployed to:", mockWETH.target);

    // Deploy Price Oracle
    console.log("\n=== Deploying Price Oracle ===");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy();
    await priceOracle.waitForDeployment();
    console.log("PriceOracle deployed to:", priceOracle.target);

    // Set asset prices (in USD with 8 decimals)
    await priceOracle.setAssetPrice(mockDAI.target, ethers.parseUnits("1", 8));
    await priceOracle.setAssetPrice(mockUSDC.target, ethers.parseUnits("1", 8));
    await priceOracle.setAssetPrice(mockWETH.target, ethers.parseUnits("2000", 8));
    console.log("Asset prices set");

    // Deploy Interest Rate Strategy
    console.log("\n=== Deploying Interest Rate Strategy ===");
    const DefaultReserveInterestRateStrategy = await ethers.getContractFactory(
        "DefaultReserveInterestRateStrategy"
    );
    const interestRateStrategy = await DefaultReserveInterestRateStrategy.deploy(
        ethers.parseUnits("0.8", 18), // optimal utilization: 80%
        ethers.parseUnits("0.02", 27), // base rate: 2% per year
        ethers.parseUnits("0.04", 27), // slope1: 4% per year
        ethers.parseUnits("0.75", 27), // slope2: 75% per year
        ethers.parseUnits("0.02", 27), // stable slope1: 2% per year
        ethers.parseUnits("0.75", 27) // stable slope2: 75% per year
    );
    await interestRateStrategy.waitForDeployment();
    console.log("InterestRateStrategy deployed to:", interestRateStrategy.target);

    // Deploy Pool
    console.log("\n=== Deploying Pool ===");
    const Pool = await ethers.getContractFactory("Pool");
    const pool = await Pool.deploy(priceOracle.target);
    await pool.waitForDeployment();
    console.log("Pool deployed to:", pool.target);

    // Deploy AToken, VariableDebtToken, and StableDebtToken for DAI
    console.log("\n=== Deploying DAI Reserve Tokens ===");
    const AToken = await ethers.getContractFactory("AToken");
    const aTokenDAI = await AToken.deploy(
        pool.target,
        mockDAI.target,
        "aToken DAI",
        "aDAI"
    );
    await aTokenDAI.waitForDeployment();
    console.log("AToken DAI deployed to:", aTokenDAI.target);

    const VariableDebtToken = await ethers.getContractFactory("VariableDebtToken");
    const variableDebtTokenDAI = await VariableDebtToken.deploy(
        pool.target,
        mockDAI.target,
        "Variable Debt DAI",
        "variableDebtDAI"
    );
    await variableDebtTokenDAI.waitForDeployment();
    console.log("VariableDebtToken DAI deployed to:", variableDebtTokenDAI.target);

    const StableDebtToken = await ethers.getContractFactory("StableDebtToken");
    const stableDebtTokenDAI = await StableDebtToken.deploy(
        pool.target,
        mockDAI.target,
        "Stable Debt DAI",
        "stableDebtDAI"
    );
    await stableDebtTokenDAI.waitForDeployment();
    console.log("StableDebtToken DAI deployed to:", stableDebtTokenDAI.target);

    // Initialize DAI reserve
    await pool.initReserve(
        mockDAI.target,
        aTokenDAI.target,
        stableDebtTokenDAI.target,
        variableDebtTokenDAI.target,
        interestRateStrategy.target
    );
    console.log("DAI reserve initialized");

    // Deploy tokens for USDC
    console.log("\n=== Deploying USDC Reserve Tokens ===");
    const aTokenUSDC = await AToken.deploy(
        pool.target,
        mockUSDC.target,
        "aToken USDC",
        "aUSDC"
    );
    await aTokenUSDC.waitForDeployment();
    console.log("AToken USDC deployed to:", aTokenUSDC.target);

    const variableDebtTokenUSDC = await VariableDebtToken.deploy(
        pool.target,
        mockUSDC.target,
        "Variable Debt USDC",
        "variableDebtUSDC"
    );
    await variableDebtTokenUSDC.waitForDeployment();
    console.log("VariableDebtToken USDC deployed to:", variableDebtTokenUSDC.target);

    const stableDebtTokenUSDC = await StableDebtToken.deploy(
        pool.target,
        mockUSDC.target,
        "Stable Debt USDC",
        "stableDebtUSDC"
    );
    await stableDebtTokenUSDC.waitForDeployment();
    console.log("StableDebtToken USDC deployed to:", stableDebtTokenUSDC.target);

    // Initialize USDC reserve
    await pool.initReserve(
        mockUSDC.target,
        aTokenUSDC.target,
        stableDebtTokenUSDC.target,
        variableDebtTokenUSDC.target,
        interestRateStrategy.target
    );
    console.log("USDC reserve initialized");

    // Deploy tokens for WETH
    console.log("\n=== Deploying WETH Reserve Tokens ===");
    const aTokenWETH = await AToken.deploy(
        pool.target,
        mockWETH.target,
        "aToken WETH",
        "aWETH"
    );
    await aTokenWETH.waitForDeployment();
    console.log("AToken WETH deployed to:", aTokenWETH.target);

    const variableDebtTokenWETH = await VariableDebtToken.deploy(
        pool.target,
        mockWETH.target,
        "Variable Debt WETH",
        "variableDebtWETH"
    );
    await variableDebtTokenWETH.waitForDeployment();
    console.log("VariableDebtToken WETH deployed to:", variableDebtTokenWETH.target);

    const stableDebtTokenWETH = await StableDebtToken.deploy(
        pool.target,
        mockWETH.target,
        "Stable Debt WETH",
        "stableDebtWETH"
    );
    await stableDebtTokenWETH.waitForDeployment();
    console.log("StableDebtToken WETH deployed to:", stableDebtTokenWETH.target);

    // Initialize WETH reserve
    await pool.initReserve(
        mockWETH.target,
        aTokenWETH.target,
        stableDebtTokenWETH.target,
        variableDebtTokenWETH.target,
        interestRateStrategy.target
    );
    console.log("WETH reserve initialized");

    console.log("\n=== Deployment Summary ===");
    console.log("Pool:", pool.target);
    console.log("PriceOracle:", priceOracle.target);
    console.log("InterestRateStrategy:", interestRateStrategy.target);
    console.log("\nMock Tokens:");
    console.log("  DAI:", mockDAI.target);
    console.log("  USDC:", mockUSDC.target);
    console.log("  WETH:", mockWETH.target);
    console.log("\nDAI Reserve:");
    console.log("  AToken:", aTokenDAI.target);
    console.log("  VariableDebtToken:", variableDebtTokenDAI.target);
    console.log("  StableDebtToken:", stableDebtTokenDAI.target);
    console.log("\nUSDC Reserve:");
    console.log("  AToken:", aTokenUSDC.target);
    console.log("  VariableDebtToken:", variableDebtTokenUSDC.target);
    console.log("  StableDebtToken:", stableDebtTokenUSDC.target);
    console.log("\nWETH Reserve:");
    console.log("  AToken:", aTokenWETH.target);
    console.log("  VariableDebtToken:", variableDebtTokenWETH.target);
    console.log("  StableDebtToken:", stableDebtTokenWETH.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
