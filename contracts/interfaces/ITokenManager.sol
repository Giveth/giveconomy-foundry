// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface ITokenManager {
    function token() external view returns (IERC20);
}
