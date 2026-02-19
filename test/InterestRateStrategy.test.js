const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DefaultReserveInterestRateStrategy", function () {
    let strategy;
    let owner;

    beforeEach(async function () {
        [owner] = await ethers.getSigners();

        const DefaultReserveInterestRateStrategy = await ethers.getContractFactory(
            "DefaultReserveInterestRateStrategy"
        );
        strategy = await DefaultReserveInterestRateStrategy.deploy(
            ethers.parseUnits("0.8", 18), // optimal utilization: 80%
            ethers.parseUnits("0.02", 27), // base rate: 2% per year
            ethers.parseUnits("0.04", 27), // slope1: 4% per year
            ethers.parseUnits("0.75", 27), // slope2: 75% per year
            ethers.parseUnits("0.02", 27), // stable slope1: 2% per year
            ethers.parseUnits("0.75", 27) // stable slope2: 75% per year
        );
        await strategy.waitForDeployment();
    });

    it("Should calculate interest rates correctly at low utilization", async function () {
        const totalLiquidity = ethers.parseUnits("1000", 18);
        const totalVariableDebt = ethers.parseUnits("200", 18); // 20% utilization

        const [liquidityRate, stableRate, variableRate] = await strategy.calculateInterestRates(
            ethers.ZeroAddress,
            0,
            0,
            0,
            totalVariableDebt,
            0,
            1000 // 10% reserve factor
        );

        expect(liquidityRate).to.be.gt(0);
        expect(variableRate).to.be.gt(0);
    });

    it("Should calculate interest rates correctly at optimal utilization", async function () {
        const totalLiquidity = ethers.parseUnits("1000", 18);
        const totalVariableDebt = ethers.parseUnits("800", 18); // 80% utilization

        const [liquidityRate, stableRate, variableRate] = await strategy.calculateInterestRates(
            ethers.ZeroAddress,
            0,
            0,
            0,
            totalVariableDebt,
            0,
            1000
        );

        expect(liquidityRate).to.be.gt(0);
        expect(variableRate).to.be.gt(0);
    });

    it("Should calculate higher rates at high utilization", async function () {
        const totalLiquidity = ethers.parseUnits("1000", 18);
        const lowDebt = ethers.parseUnits("200", 18);
        const highDebt = ethers.parseUnits("950", 18);

        const [lowLiquidityRate, , lowVariableRate] = await strategy.calculateInterestRates(
            ethers.ZeroAddress,
            0,
            0,
            0,
            lowDebt,
            0,
            1000
        );

        const [highLiquidityRate, , highVariableRate] = await strategy.calculateInterestRates(
            ethers.ZeroAddress,
            0,
            0,
            0,
            highDebt,
            0,
            1000
        );

        expect(highVariableRate).to.be.gt(lowVariableRate);
    });
});
