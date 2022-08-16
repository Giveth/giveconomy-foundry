// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/console.sol';

import 'contracts/GIVpower.sol';
import 'contracts/GardenUnipoolTokenDistributor.sol';
import './interfaces/IERC20Bridged.sol';
import './GIVpowerTest.sol';

contract CalculatePowerTest is GIVpowerTest {
    function setUp() public override {
        super.setUp();
        string[] memory runJsInputs = new string[](5);

        // Build ffi command string
        runJsInputs[0] = 'npm';
        runJsInputs[1] = '--prefix';
        runJsInputs[2] = 'test/calculatePower_testing/';
        runJsInputs[3] = '--silent';
        runJsInputs[4] = 'i';

        vm.ffi(runJsInputs);
    }

    function testSqrt(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();

        vm.assume(rounds > 0);
        vm.assume(rounds <= maxLockRounds);
        vm.assume(amount < MAX_GIV_BALANCE);

        string[] memory runJsInputs = new string[](4);

        // Build ffi command string
        runJsInputs[0] = 'node';
        runJsInputs[1] = 'test/calculatePower_testing/calculatePower.js';
        runJsInputs[2] = vm.toString(amount);
        runJsInputs[3] = vm.toString(rounds);

        // Run command and capture output
        bytes memory jsResult = vm.ffi(runJsInputs);
        uint256 jsPowerAmount = uint256(abi.decode(jsResult, (bytes32)));
        uint256 calculatePower = givPower.calculatePower(amount, rounds);

        // The precision is 1-e9
        assertApproxEqRel(calculatePower, jsPowerAmount, 0.000000001e18);
    }
}
