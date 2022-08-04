// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import "forge-std/Script.sol";

import "src/GivPower.sol";

contract GivPowerScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // new GivPower();

        vm.stopBroadcast();
    }
}
