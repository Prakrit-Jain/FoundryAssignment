// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "forge-std/Test.sol";

import "../src/interfaces/IAsset.sol";
import "../src/interfaces/IVault.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IBalancerPool.sol";
import "../src/libraries/Helpers.sol";

contract ContractTest is Test {
    address USDC_ETH_MIRROR = vm.envAddress("USDC_ETH_MIRROR");
    address USDC_AVAX_MIRROR = vm.envAddress("USDC_AVAX_MIRROR");
    address AXON_TEST_KAI = vm.envAddress("AXON_TEST_KAI");
    address AXON_USDCETH_KAI_BPT = vm.envAddress("AXON_USDCETH_KAI_BPT");
    address AXON_USDCAVAX_KAI_BPT = vm.envAddress("AXON_USDCAVAX_KAI_BPT");
    address TOKEN_ADMIN = vm.envAddress("TOKEN_ADMIN");
    address VAULT;
    bytes32 poolIdOfAXON_USDCETH_KAIPool;
    bytes32 poolIdOfAXON_USDCAVAX_KAIPool;

    function setUp() public {
        vm.createSelectFork("khalani");
        VAULT = IBalancerPool(AXON_USDCETH_KAI_BPT).getVault();
        poolIdOfAXON_USDCETH_KAIPool = IBalancerPool(AXON_USDCETH_KAI_BPT).getPoolId();
        poolIdOfAXON_USDCAVAX_KAIPool = IBalancerPool(AXON_USDCAVAX_KAI_BPT).getPoolId();
    }

    /**
     * @dev This function tests the swap functionality from USDC_ETH_MIRROR to USDC_AVAX_MIRROR via AXON_TEST_KAI tokens.
     * It uses a batch swap involving two steps:
     * 1. Swapping USDC_ETH_MIRROR for AXON_TEST_KAI.
     * 2. Swapping AXON_TEST_KAI for USDC_AVAX_MIRROR.
     * The function approves the VAULT contract to spend USDC_ETH_MIRROR tokens, defines the swap details, and executes
     * the swap.
     */
    function testSwapUSDCEthForAvax() external {
        IVault vault = IVault(VAULT);
        uint256 decimals = IERC20(USDC_ETH_MIRROR).decimals();
        console.log(decimals);

        vm.prank(TOKEN_ADMIN);
        IERC20(USDC_ETH_MIRROR).mint(address(this), 2800 * (10 ** decimals));
        IERC20(USDC_ETH_MIRROR).approve(VAULT, 2800 * (10 ** decimals));

        IAsset[] memory _assets = new IAsset[](3);
        _assets[0] = IAsset(USDC_ETH_MIRROR);
        _assets[1] = IAsset(AXON_TEST_KAI);
        _assets[2] = IAsset(USDC_AVAX_MIRROR);

        Helpers.BatchSwapStep memory batchSwap1 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCETH_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: 2800 * (10 ** decimals),
            userData: bytes("")
        });

        Helpers.BatchSwapStep memory batchSwap2 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCAVAX_KAIPool,
            assetInIndex: 1,
            assetOutIndex: 2,
            amount: 0,
            userData: bytes("")
        });

        Helpers.BatchSwapStep[] memory swaps = new Helpers.BatchSwapStep[](2);

        swaps[0] = batchSwap1;
        swaps[1] = batchSwap2;

        Helpers.FundManagement memory funds = Helpers.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        int256[] memory limits;
        limits = vault.queryBatchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds);
        uint256 deadline = block.timestamp + 5 minutes;

        for (uint256 i = 0; i < 3; i++) {
            limits[i] = limits[i] < 0 ? (limits[i] * 99) / 100 : limits[i];
        }

        vault.batchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds, limits, deadline);
    }

    /**
     * @dev This function tests the swap functionality from USDC_ETH_MIRROR to AXON_TEST_KAI tokens.
     * It performs a single swap by providing USDC_ETH_MIRROR as the input asset and receiving AXON_TEST_KAI as
     * the output asset.
     * The function approves the VAULT contract to spend USDC_ETH_MIRROR tokens, defines the swap details, and executes
     * the swap.
     */
    function testSwapUSDCEthForKai() external {
        uint256 decimals = IERC20(USDC_ETH_MIRROR).decimals();

        vm.prank(TOKEN_ADMIN);
        IERC20(USDC_ETH_MIRROR).mint(address(this), 2800 * (10 ** decimals));

        IERC20(USDC_ETH_MIRROR).approve(VAULT, 2800 * (10 ** decimals));

        Helpers.SingleSwap memory singleSwap = Helpers.SingleSwap({
            poolId: poolIdOfAXON_USDCETH_KAIPool,
            kind: Helpers.SwapKind.GivenIn,
            assetIn: IAsset(USDC_ETH_MIRROR),
            assetOut: IAsset(AXON_TEST_KAI),
            amount: 2800 * (10 ** decimals),
            userData: bytes("")
        });

        Helpers.FundManagement memory funds = Helpers.FundManagement({
            sender: address(this),
            fromInternalBalance: true,
            recipient: payable(address(this)),
            toInternalBalance: true
        });

        uint256 limit = 2700 * (10 ** decimals);
        uint256 deadline = block.timestamp + 5 minutes;
        IVault vault = IVault(VAULT);

        vault.swap(singleSwap, funds, limit, deadline);
    }

    /**
     * @dev This function tests the add liquidity functionality for the USDC_ETH_USDC_KAIPool.
     * It add liquidity using a batch swap involving two steps to add liquidity to the pool:
     * 1. Swaps AXON_TEST_KAI for AXON_USDCETH_KAI_BPT tokens.
     * 2. Swaps USDC_ETH_MIRROR for AXON_USDCETH_KAI_BPT tokens.
     */
    function testAddLiquidityForUSDC_ETH_USDC_KAIPool() public returns (int256[] memory amountCalculated) {
        uint256 decimalsEth = IERC20(USDC_ETH_MIRROR).decimals();
        uint256 decimalsKai = IERC20(AXON_TEST_KAI).decimals();

        vm.startPrank(TOKEN_ADMIN);
        IERC20(USDC_ETH_MIRROR).mint(address(this), 2800 * (10 ** decimalsEth));
        IERC20(AXON_TEST_KAI).mint(address(this), 2800 * (10 ** decimalsKai));
        vm.stopPrank();

        IERC20(USDC_ETH_MIRROR).approve(VAULT, 2800 * (10 ** decimalsEth));
        IERC20(AXON_TEST_KAI).approve(VAULT, 2800 * (10 ** decimalsKai));

        IAsset[] memory _assets = new IAsset[](3);
        _assets[0] = IAsset(AXON_TEST_KAI);
        _assets[1] = IAsset(USDC_ETH_MIRROR);
        _assets[2] = IAsset(AXON_USDCETH_KAI_BPT);

        Helpers.BatchSwapStep memory batchSwap1 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCETH_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 2,
            amount: 2800 * (10 ** decimalsKai),
            userData: bytes("")
        });

        Helpers.BatchSwapStep memory batchSwap2 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCETH_KAIPool,
            assetInIndex: 1,
            assetOutIndex: 2,
            amount: 2800 * (10 ** decimalsEth),
            userData: bytes("")
        });

        Helpers.BatchSwapStep[] memory swaps = new Helpers.BatchSwapStep[](2);

        swaps[0] = batchSwap1;
        swaps[1] = batchSwap2;

        Helpers.FundManagement memory funds = Helpers.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        IVault vault = IVault(VAULT);

        int256[] memory limits;
        limits = vault.queryBatchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds);
        for (uint256 i = 0; i < 3; i++) {
            limits[i] = limits[i] < 0 ? (limits[i] * 99) / 100 : limits[i];
        }
        uint256 deadline = block.timestamp + 5 minutes;

        amountCalculated = vault.batchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds, limits, deadline);
    }

    /**
     * @dev This function tests the add liquidity functionality for the USDC_AVAX_USDC_KAIPool.
     * It add liquidity using a batch swap involving two steps to add liquidity to the pool:
     * 1. Swaps AXON_TEST_KAI for AXON_USDCAVAX_KAI_BPT tokens.
     * 2. Swaps USDC_AVAX_MIRROR for AXON_USDCAVAX_KAI_BPT tokens.
     */
    function testAddLiquidityForUSDC_AVAX_USDC_KAIPool() public returns (int256[] memory amountCalculated) {
        uint256 decimalsAVAX = IERC20(USDC_AVAX_MIRROR).decimals();
        uint256 decimalsKai = IERC20(AXON_TEST_KAI).decimals();

        vm.startPrank(TOKEN_ADMIN);
        IERC20(USDC_AVAX_MIRROR).mint(address(this), 2800 * (10 ** decimalsAVAX));
        IERC20(AXON_TEST_KAI).mint(address(this), 2800 * (10 ** decimalsKai));
        vm.stopPrank();

        IERC20(USDC_AVAX_MIRROR).approve(VAULT, 2800 * (10 ** decimalsAVAX));
        IERC20(AXON_TEST_KAI).approve(VAULT, 2800 * (10 ** decimalsKai));

        IAsset[] memory _assets = new IAsset[](3);
        _assets[0] = IAsset(USDC_AVAX_MIRROR);
        _assets[1] = IAsset(AXON_TEST_KAI);
        _assets[2] = IAsset(AXON_USDCAVAX_KAI_BPT);

        IVault vault = IVault(VAULT);

        Helpers.BatchSwapStep memory batchSwap1 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCAVAX_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 2,
            amount: 2800 * (10 ** decimalsAVAX),
            userData: bytes("")
        });

        Helpers.BatchSwapStep memory batchSwap2 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCAVAX_KAIPool,
            assetInIndex: 1,
            assetOutIndex: 2,
            amount: 2800 * (10 ** decimalsKai),
            userData: bytes("")
        });

        Helpers.BatchSwapStep[] memory swaps = new Helpers.BatchSwapStep[](2);

        swaps[0] = batchSwap1;
        swaps[1] = batchSwap2;

        Helpers.FundManagement memory funds = Helpers.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        int256[] memory limits;
        limits = vault.queryBatchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds);
        for (uint256 i = 0; i < 3; i++) {
            limits[i] = limits[i] < 0 ? (limits[i] * 99) / 100 : limits[i];
        }
        uint256 deadline = block.timestamp + 5 minutes;

        amountCalculated = vault.batchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds, limits, deadline);
    }

    /**
     * @dev This function tests the withdraw liquidity functionality for the USDC_ETH_USDC_KAIPool.
     * It performs a batch swap involving two steps to withdraw liquidity from the pool:
     * 1. Swaps Half of AXON_USDCETH_KAI_BPT for USDC_ETH_MIRROR tokens.
     * 2. Swaps another Half of AXON_USDCETH_KAI_BPT for AXON_TEST_KAI tokens.
     * The function executes the batch swap, and withdraws the liquidity from the pool.
     */
    function testWithdrawLiquidityForUSDC_ETH_USDC_KAIPool() external {
        int256[] memory amountReceived = testAddLiquidityForUSDC_ETH_USDC_KAIPool();
        uint256 amountOfBpt = uint256(-(amountReceived[2]));
        uint256 amountOfBptInForEth = amountOfBpt / 2;
        uint256 amountOfBptInForKai = amountOfBpt - amountOfBptInForEth;

        IAsset[] memory _assets = new IAsset[](3);
        _assets[0] = IAsset(AXON_USDCETH_KAI_BPT);
        _assets[1] = IAsset(USDC_ETH_MIRROR);
        _assets[2] = IAsset(AXON_TEST_KAI);

        Helpers.BatchSwapStep memory batchSwap1 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCETH_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: amountOfBptInForEth,
            userData: bytes("")
        });

        Helpers.BatchSwapStep memory batchSwap2 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCETH_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 2,
            amount: amountOfBptInForKai,
            userData: bytes("")
        });

        Helpers.BatchSwapStep[] memory swaps = new Helpers.BatchSwapStep[](2);

        swaps[0] = batchSwap1;
        swaps[1] = batchSwap2;

        Helpers.FundManagement memory funds = Helpers.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        IVault vault = IVault(VAULT);

        int256[] memory limits;
        limits = vault.queryBatchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds);
        for (uint256 i = 0; i < 3; i++) {
            limits[i] = limits[i] < 0 ? (limits[i] * 99) / 100 : limits[i];
        }
        uint256 deadline = block.timestamp + 5 minutes;

        vault.batchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds, limits, deadline);
    }

    /**
     * @dev This function tests the withdraw liquidity functionality for the USDC_AVAX_USDC_KAIPool.
     * It performs a batch swap involving two steps to withdraw liquidity from the pool:
     * 1. Swaps Half of AXON_USDCAVAX_KAI_BPT for USDC_AVAX_MIRROR tokens.
     * 2. Swaps Another Half of AXON_USDCAVAX_KAI_BPT for AXON_TEST_KAI tokens.
     * The function executes the batch swap, and withdraws the liquidity from the pool.
     */
    function testWithdrawLiquidityForUSDC_AVAX_USDC_KAIPool() external {
        int256[] memory amountReceived = testAddLiquidityForUSDC_AVAX_USDC_KAIPool();
        uint256 amountOfBpt = uint256(-(amountReceived[2]));
        uint256 amountOfBptInForAVAX = amountOfBpt / 2;
        uint256 amountOfBptInForKAI = amountOfBpt - amountOfBptInForAVAX;

        IAsset[] memory _assets = new IAsset[](3);
        _assets[0] = IAsset(AXON_USDCAVAX_KAI_BPT);
        _assets[1] = IAsset(USDC_AVAX_MIRROR);
        _assets[2] = IAsset(AXON_TEST_KAI);

        Helpers.BatchSwapStep memory batchSwap1 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCAVAX_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: amountOfBptInForAVAX,
            userData: bytes("")
        });

        Helpers.BatchSwapStep memory batchSwap2 = Helpers.BatchSwapStep({
            poolId: poolIdOfAXON_USDCAVAX_KAIPool,
            assetInIndex: 0,
            assetOutIndex: 2,
            amount: amountOfBptInForKAI,
            userData: bytes("")
        });

        Helpers.BatchSwapStep[] memory swaps = new Helpers.BatchSwapStep[](2);

        swaps[0] = batchSwap1;
        swaps[1] = batchSwap2;

        Helpers.FundManagement memory funds = Helpers.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        IVault vault = IVault(VAULT);

        int256[] memory limits;
        limits = vault.queryBatchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds);
        for (uint256 i = 0; i < 3; i++) {
            limits[i] = limits[i] < 0 ? (limits[i] * 99) / 100 : limits[i];
        }
        uint256 deadline = block.timestamp + 5 minutes;

        vault.batchSwap(Helpers.SwapKind.GivenIn, swaps, _assets, funds, limits, deadline);
    }
}
