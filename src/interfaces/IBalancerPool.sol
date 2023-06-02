// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

/**
 *@dev Interface for interacting with a Balancer pool contract.
 */
interface IBalancerPool {

    /**
     * @dev Retreives the address of the vault associated with the Balancer pool.
     */
    function getVault() external returns (address);

    /**
     * @dev Retreives the ID of the pool.
     */ 
    function getPoolId() external returns (bytes32);
}
