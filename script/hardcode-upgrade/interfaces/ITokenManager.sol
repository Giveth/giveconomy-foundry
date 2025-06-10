// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

interface ITokenManager {
    function token() external view returns (IERC20);

    function wrappableToken() external view returns (IERC20);

    function wrap(uint256) external;

    function unwrap(uint256) external;
}
