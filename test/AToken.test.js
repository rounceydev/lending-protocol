const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("AToken", function () {
    async function deployATokenFixture() {
        const [owner, user1] = await ethers.getSigners();

        const MockDAI = await ethers.getContractFactory("MockDAI");
        const mockDAI = await MockDAI.deploy();
        await mockDAI.waitForDeployment();

        const Pool = await ethers.getContractFactory("Pool");
        const PriceOracle = await ethers.getContractFactory("PriceOracle");
        const priceOracle = await PriceOracle.deploy();
        await priceOracle.waitForDeployment();

        const pool = await Pool.deploy(priceOracle.target);
        await pool.waitForDeployment();

        const AToken = await ethers.getContractFactory("AToken");
        const aToken = await AToken.deploy(
            pool.target,
            mockDAI.target,
            "aToken DAI",
            "aDAI"
        );
        await aToken.waitForDeployment();

        return { owner, user1, aToken, mockDAI, pool };
    }

    describe("Deployment", function () {
        it("Should set the right underlying asset", async function () {
            const { aToken, mockDAI } = await loadFixture(deployATokenFixture);
            expect(await aToken.UNDERLYING_ASSET_ADDRESS()).to.equal(mockDAI.target);
        });

        it("Should set the right pool address", async function () {
            const { aToken, pool } = await loadFixture(deployATokenFixture);
            expect(await aToken.POOL()).to.equal(pool.target);
        });
    });

    describe("Mint and Burn", function () {
        it("Should only allow pool to mint", async function () {
            const { aToken, user1 } = await loadFixture(deployATokenFixture);
            await expect(
                aToken.connect(user1).mint(user1.address, ethers.parseUnits("100", 27))
            ).to.be.revertedWith("CALLER_MUST_BE_POOL");
        });

        it("Should only allow pool to burn", async function () {
            const { aToken, pool, user1 } = await loadFixture(deployATokenFixture);
            await expect(
                aToken.connect(pool).burn(user1.address, ethers.parseUnits("100", 27))
            ).to.not.be.reverted;
        });
    });
});
