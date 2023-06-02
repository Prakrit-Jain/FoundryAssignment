// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

interface IERC20 {
    /**
     * @dev Mints a specified amount of tokens and assigns them to the specified recipient.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Approves the specified spender to spend up to the specified amount of tokens on behalf of the caller.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Retrieves the token balance of the specified account.
     */
    function balanceOf(address account) external returns (uint256);

    /**
     * @dev Retrieves the number of decimal places used by the token.
     */
    function decimals() external returns (uint8);

    /**
     * @dev Transfer the `amount` number of tokens to `to` address.
     */
    function transfer(address to, uint256 amount) external returns (bool);
}
