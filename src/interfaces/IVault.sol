// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "../libraries/Helpers.sol";

interface IVault {
    /**
     * @notice Performs a single asset swap operation.
     * This function swaps an input asset for an output asset according to the specified parameters.
     */
    function swap(
        Helpers.SingleSwap memory singleSwap,
        Helpers.FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256 amountCalculated);
    /**
    @notice Queries the expected asset deltas for a batch swap operation.
    *This function calculates the expected changes in asset balances for a batch swap operation without executing the swaps.
    */
    function queryBatchSwap(
        Helpers.SwapKind kind,
        Helpers.BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        Helpers.FundManagement memory funds
    ) external returns (int256[] memory assetDeltas);

    
    /**
    *@notice Executes a batch swap operation.
    *@dev This function performs a batch swap operation based on the given parameters.
    */
    function batchSwap(
        Helpers.SwapKind kind,
        Helpers.BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        Helpers.FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external returns (int256[] memory assetDeltas);
}
