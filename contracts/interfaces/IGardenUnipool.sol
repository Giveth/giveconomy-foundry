// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

interface IGardenUnipool {
    function stakeGivPower(address user, uint256 amount) external;

    function withdrawGivPower(address user, uint256 amount) external;
}
