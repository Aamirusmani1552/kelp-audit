// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import { LRTConfigTest, ILRTConfig, LRTConstants, UtilLib } from "./LRTConfigTest.t.sol";
import { IStrategy } from "src/interfaces/IStrategy.sol";
import { NodeDelegator } from "src/NodeDelegator.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { RSETH } from "../src/RSETH.sol";
import { LRTDepositPool } from "../src/LRTDepositPool.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IStrategyManager } from "./test-interfaces/IStrategyManager.sol";
import { IEigenPodManager } from "./test-interfaces/IEigenPodManager.sol";
import { LRTOracle } from "../src/LRTOracle.sol";
import { LRTConfig } from "../src/LRTConfig.sol";
import { console2 } from "forge-std/console2.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ChainlinkPriceOracle } from "../src/oracles/ChainlinkPriceOracle.sol";

contract MockEigenStrategyManager {
    mapping(address depositor => mapping(address strategy => uint256 shares)) public depositorStrategyShareBalances;

    address[] public strategies;

    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares) {
        token.transferFrom(msg.sender, address(strategy), amount);

        shares = amount;

        depositorStrategyShareBalances[msg.sender][address(strategy)] += shares;

        strategies.push(address(strategy));

        return shares;
    }

    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory) {
        uint256[] memory shares = new uint256[](strategies.length);
        IStrategy[] memory strategies_ = new IStrategy[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            strategies_[i] = IStrategy(strategies[i]);
            shares[i] = depositorStrategyShareBalances[depositor][strategies[i]];
        }

        return (strategies_, shares);
    }
}

contract MockStrategy {
    IERC20 public underlyingToken_;
    uint256 public mockUserUnderlyingViewBal;

    constructor(address _underlyingToken, uint256 _mockUserUnderlyingViewBal) {
        underlyingToken_ = IERC20(_underlyingToken);

        mockUserUnderlyingViewBal = _mockUserUnderlyingViewBal;
    }

    function underlyingToken() external view returns (IERC20) {
        return underlyingToken_;
    }

    function userUnderlyingView(address) external view returns (uint256) {
        return mockUserUnderlyingViewBal;
    }

    // not present in original implementation. added just for testing
    function addTokens(uint256 amount) external {
        mockUserUnderlyingViewBal += amount;
    }
}

contract MockUSDC is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

contract MockPriceAggregator {
    function latestAnswer() external pure returns (uint256) {
        return 1 ether;
    }
}

contract BaseIntegrationTest is BaseTest {
    NodeDelegator public nodeDel;
    LRTConfig public lrtConfig;
    LRTOracle public lrtOracle;
    RSETH public rsETH;
    LRTDepositPool public lrtDepositPool;
    ChainlinkPriceOracle public chainlinkPriceOracle;
    MockPriceAggregator public mockPriceAggregator;

    // proxies contracts
    NodeDelegator public nodeDelP;
    LRTConfig public lrtConfigP;
    LRTOracle public lrtOracleP;
    RSETH public rsETHP;
    LRTDepositPool public lrtDepositPoolP;
    ChainlinkPriceOracle public chainlinkPriceOracleP;

    // mainnet contracts addresses
    IStrategyManager public strategyManager = IStrategyManager(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IEigenPodManager public eigenPodManager = IEigenPodManager(0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338);

    address manager = makeAddr("manager");

    // roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // mocks
    MockEigenStrategyManager public mockEigenStrategyManager;
    MockStrategy public rETHMockStrategy;
    MockStrategy public cbETHMockStrategy;
    MockStrategy public stETHMockStrategy;
    MockUSDC public usdc;
    address public mockLRTDepositPool;
    uint256 public mockUserUnderlyingViewBalance;

    function setUp() public virtual override {
        super.setUp();

        // creating proxy admin
        vm.startPrank(admin);
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        vm.stopPrank();

        // deploying different contracts
        lrtConfig = new LRTConfig();
        lrtOracle = new LRTOracle();
        rsETH = new RSETH();
        lrtDepositPool = new LRTDepositPool();
        usdc = new MockUSDC("USDC", "USDC");
        nodeDel = new NodeDelegator();
        chainlinkPriceOracle = new ChainlinkPriceOracle();
        mockPriceAggregator = new MockPriceAggregator();

        // creating Proxy for different contracts
        TransparentUpgradeableProxy lrtConfigProxy = new TransparentUpgradeableProxy(
            address(lrtConfig),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy lrtOracleProxy = new TransparentUpgradeableProxy(
            address(lrtOracle),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy rsETHProxy = new TransparentUpgradeableProxy(
            address(rsETH),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy lrtDepositPoolProxy = new TransparentUpgradeableProxy(
            address(lrtDepositPool),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy nodeDelProxy = new TransparentUpgradeableProxy(
            address(nodeDel),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy chainlinkPriceOracleProxy = new TransparentUpgradeableProxy(
            address(chainlinkPriceOracle),
            address(proxyAdmin),
            ""
        );

        // minting usdc to users: 100k each
        usdc.mint(alice, 100_000 ether);
        usdc.mint(bob, 100_000 ether);
        usdc.mint(carol, 100_000 ether);

        // converting different proxies
        lrtConfigP = LRTConfig(address(lrtConfigProxy));
        lrtOracleP = LRTOracle(address(lrtOracleProxy));
        rsETHP = RSETH(address(rsETHProxy));
        lrtDepositPoolP = LRTDepositPool(address(lrtDepositPoolProxy));
        nodeDelP = NodeDelegator(address(nodeDelProxy));
        chainlinkPriceOracleP = ChainlinkPriceOracle(address(chainlinkPriceOracleProxy));

        // initialize different contracts
        lrtConfigP.initialize(admin, address(stETH), address(rETH), address(cbETH), address(rsETHP));
        lrtOracleP.initialize(address(lrtConfigP));
        rsETHP.initialize(admin, address(lrtConfigP));
        lrtDepositPoolP.initialize(address(lrtConfigP));
        nodeDelP.initialize(address(lrtConfigP));
        chainlinkPriceOracleP.initialize(address(lrtConfigP));

        ///////////////////////////
        // configuring mocks //////
        ///////////////////////////

        // add mockEigenStrategyManager to LRTConfig
        mockEigenStrategyManager = new MockEigenStrategyManager();
        vm.startPrank(admin);
        lrtConfigP.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, address(mockEigenStrategyManager));

        // add manager role
        lrtConfigP.grantRole(LRTConstants.MANAGER, manager);

        // add mockStrategy to LRTConfig
        mockUserUnderlyingViewBalance = 0;
        rETHMockStrategy = new MockStrategy(address(rETH), mockUserUnderlyingViewBalance);
        cbETHMockStrategy = new MockStrategy(address(cbETH), mockUserUnderlyingViewBalance);
        stETHMockStrategy = new MockStrategy(address(stETH), mockUserUnderlyingViewBalance);

        // updating strategy for tokens
        lrtConfigP.updateAssetStrategy(address(rETH), address(rETHMockStrategy));
        lrtConfigP.updateAssetStrategy(address(cbETH), address(cbETHMockStrategy));
        lrtConfigP.updateAssetStrategy(address(stETH), address(stETHMockStrategy));

        // adding lrtDepositPool to LRTConfig
        lrtConfigP.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolP));
        lrtConfigP.setContract(LRTConstants.LRT_ORACLE, address(lrtOracleP));
        vm.stopPrank();

        // setting up price feeds
        vm.startPrank(manager);
        chainlinkPriceOracleP.updatePriceFeedFor(address(rETH), address(mockPriceAggregator));
        chainlinkPriceOracleP.updatePriceFeedFor(address(cbETH), address(mockPriceAggregator));
        chainlinkPriceOracleP.updatePriceFeedFor(address(stETH), address(mockPriceAggregator));
        vm.stopPrank();

        // setting up oracles
        // using same oracle for both for now
        vm.startPrank(manager);
        lrtOracleP.updatePriceOracleFor(address(rETH), address(chainlinkPriceOracleP));
        lrtOracleP.updatePriceOracleFor(address(cbETH), address(chainlinkPriceOracleP));
        lrtOracleP.updatePriceOracleFor(address(stETH), address(chainlinkPriceOracleP));
        vm.stopPrank();

        // giving minter role to deposit pool
        vm.startPrank(admin);
        rsETHP.grantRole(MINTER_ROLE, address(lrtDepositPoolP));
        vm.stopPrank();

        // adding node delegator to the lrtDepositPool
        address[] memory nodeDelegatorAddresses = new address[](1);
        nodeDelegatorAddresses[0] = address(nodeDelP);

        vm.startPrank(admin);
        lrtDepositPoolP.addNodeDelegatorContractToQueue(nodeDelegatorAddresses);
        vm.stopPrank();

        /////////////////
        /// labeling ///
        /////////////////
        {
            vm.label(address(lrtConfigP), "lrtConfigP");
            vm.label(address(lrtOracleP), "lrtOracleP");
            vm.label(address(rsETHP), "rsETHP");
            vm.label(address(lrtDepositPoolP), "lrtDepositPoolP");
            vm.label(address(nodeDelP), "nodeDelP");
            vm.label(address(chainlinkPriceOracleP), "chainlinkPriceOracleP");
            vm.label(address(mockEigenStrategyManager), "mockEigenStrategyManager");
            vm.label(address(rETHMockStrategy), "rETHMockStrategy");
            vm.label(address(cbETHMockStrategy), "cbETHMockStrategy");
            vm.label(address(stETHMockStrategy), "stETHMockStrategy");
            vm.label(address(usdc), "usdc");
            vm.label(address(cbETH), "cbETH");
            vm.label(address(rETH), "rETH");
            vm.label(address(stETH), "stETH");
        }
    }

    // @audit potential issue
    function test_SameNodeDelegatorsCanBeAddedTwiceThatWillGiveIncorrectData() public {
        // adding some tokens to the pool
        uint256 amount = 500 ether;
        vm.prank(alice);
        uint256 amountOfRSETHMintedToAlice = depositAssetToPool(address(cbETH), amount, alice, 1);

        // transferring rewards to node delegator
        // necessary to make the situation work.
        vm.prank(manager);
        lrtDepositPoolP.transferAssetToNodeDelegator(0, address(cbETH), amount);

        // adding same node delegator again
        address[] memory nodeDelegatorAddresses = new address[](1);
        nodeDelegatorAddresses[0] = address(nodeDelP);

        vm.startPrank(admin);
        lrtDepositPoolP.addNodeDelegatorContractToQueue(nodeDelegatorAddresses);
        vm.stopPrank();

        // checking if node delegator is added
        address[] memory addedAddresses = lrtDepositPoolP.getNodeDelegatorQueue();
        assertEq(addedAddresses.length, 2, "length is not same");

        // checking if node delegator addresses are same
        for (uint8 i; i < addedAddresses.length; i++) {
            assertEq(addedAddresses[i], address(nodeDelP), "addresses are not same");
        }

        console2.log("Amount To Deposit: %s", amount);
        uint256 tokenToRSETHAmount = lrtDepositPoolP.getRsETHAmountToMint(address(cbETH), amount);
        console2.log("Amount of RSETH Tokens to Recieve: %s", tokenToRSETHAmount);

        // depositing again to check how many we will receive
        amountOfRSETHMintedToAlice = depositAssetToPool(address(cbETH), amount, alice, 2);
        console2.log("Amount of token Received After Deposit: %s", amountOfRSETHMintedToAlice);

        // can't do this because of another vulnerability in the code
        // assertEq(amountOfRSETHMintedToAlice, tokenToRSETHAmount, "amount is not same");
    }

    function test_SameTestAsAboveWithoutAddingDuplicateNodeDelegator() public {
        // adding some tokens to the pool
        uint256 amount = 500 ether;
        vm.prank(alice);
        uint256 amountOfRSETHMintedToAlice = depositAssetToPool(address(cbETH), amount, alice, 1);

        // transferring rewards to node delegator
        // necessary to make the situation work.
        vm.prank(manager);
        lrtDepositPoolP.transferAssetToNodeDelegator(0, address(cbETH), amount);

        console2.log("Deposit Amount: %s", amount);
        uint256 tokenToRSETHAmount = lrtDepositPoolP.getRsETHAmountToMint(address(cbETH), amount);
        console2.log("Amount of RSETH Tokens to Recieve: %s", tokenToRSETHAmount);

        // depositing again to check how many we will receive
        amountOfRSETHMintedToAlice = depositAssetToPool(address(cbETH), amount, alice, 2);
        console2.log("Amount of token Received After Deposit: %s", amountOfRSETHMintedToAlice);

        // can't do this because of another vulnerability in the code
        // assertEq(amountOfRSETHMintedToAlice, tokenToRSETHAmount, "amount is not same");
    }

    function test_depositToPool() public {
        uint256 amount = 500 ether;
        uint256 userBalanceBefore = IERC20(cbETH).balanceOf(alice);
        (uint256 rsEthMinted) = depositAssetToPool(address(cbETH), amount, alice, 1);
        uint256 userBalanceAfter = IERC20(cbETH).balanceOf(alice);

        assertEq(userBalanceBefore - userBalanceAfter, amount, "amount is not same");
    }

    // @audit potential issue
    function test_depositToPoolMultipleTimes() public {
        uint256 amount = 500 ether;

        for (uint256 i; i < 5; i++) {
            // minting tokens to user to make sure he has enough tokens
            cbETH.mint(alice, amount);

            uint256 userBalanceBefore = IERC20(cbETH).balanceOf(alice);
            (uint256 rsEthMinted) = depositAssetToPool(address(cbETH), amount, alice, i + 1);
            uint256 userBalanceAfter = IERC20(cbETH).balanceOf(alice);

            assertEq(userBalanceBefore - userBalanceAfter, amount, "amount is not same");
        }
    }

    function test_depositToPoolMultipleTimesDifferentAmount() public {
        uint256 amount = 500 ether;
        uint256 amount2 = 20_000 ether;

        // minting tokens to user to make sure he has enough tokens
        cbETH.mint(alice, amount + amount2);

        uint256 userBalanceBefore = IERC20(cbETH).balanceOf(alice);
        (uint256 rsEthMinted) = depositAssetToPool(address(cbETH), amount, alice, 1);
        uint256 userBalanceAfter = IERC20(cbETH).balanceOf(alice);
        assertEq(userBalanceBefore - userBalanceAfter, amount, "amount is not same");

        userBalanceBefore = IERC20(cbETH).balanceOf(alice);
        (rsEthMinted) = depositAssetToPool(address(cbETH), amount2, alice, 2);
        userBalanceAfter = IERC20(cbETH).balanceOf(alice);

        assertEq(userBalanceBefore - userBalanceAfter, amount2, "amount is not same");
    }

    function testFuzz_depositToPool(uint256 amount) public {
        vm.assume(amount > 0 && amount < 100_000_000_000 ether);

        // minting tokens equal to amount to alice
        cbETH.mint(alice, amount);

        // updating asset deposit limit in the config
        vm.startPrank(manager);
        lrtConfigP.updateAssetDepositLimit(address(cbETH), amount + 100 ether);
        vm.stopPrank();

        uint256 userBalanceBefore = IERC20(cbETH).balanceOf(alice);
        (uint256 rsEthMinted) = depositAssetToPool(address(cbETH), amount, alice, 1);
        uint256 userBalanceAfter = IERC20(cbETH).balanceOf(alice);

        assertEq(userBalanceBefore - userBalanceAfter, amount, "amount is not same");
    }

    function depositAssetToPool(
        address asset,
        uint256 amount,
        address from,
        uint256 run
    )
        internal
        returns (uint256 rsETHMintedToUser)
    {
        // balance before deposit
        uint256 balanceBefore = IERC20(asset).balanceOf(address(lrtDepositPoolP));
        uint256 userRSETHBalance = IERC20(address(rsETHP)).balanceOf(from);

        // depositing asset to pool
        vm.startPrank(from);
        IERC20(asset).approve(address(lrtDepositPoolP), amount);
        lrtDepositPoolP.depositAsset(asset, amount);
        vm.stopPrank();

        // balance after deposit
        uint256 balanceAfter = IERC20(asset).balanceOf(address(lrtDepositPoolP));
        uint256 userRSETHBalanceAfter = IERC20(address(rsETHP)).balanceOf(from);

        // logging balances

        console2.log("\n");
        console2.log("------------------------ Run %s:  Deposit Info  ------------------------\n", run);
        console2.log("Deposit Amount: %s", amount);
        console2.log("LRTDepositPool Balance Before Deposit: %s", balanceBefore);
        console2.log("LRTDepositPool Balance After Deposit: %s", balanceAfter);
        console2.log("Change in Balance of LRTDepositPool: %s", balanceAfter - balanceBefore);
        console2.log("RSETH Minted to User: %s", userRSETHBalanceAfter - userRSETHBalance);
        console2.log("TotalSupply of RSETH: %s\n", rsETHP.totalSupply());
        console2.log("------------------------------------------------------------------------\n");

        // checking if asset is deposited
        assertEq(balanceAfter - balanceBefore, amount, "amount is not same");

        // returning minted amount of RSETH
        return userRSETHBalanceAfter - userRSETHBalance;
    }
}
