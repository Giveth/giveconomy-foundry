// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.10;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

interface IERC20Bridged is IERC20 {
    function mint(address, uint256) external returns (bool);
}
