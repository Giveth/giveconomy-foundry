// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import "forge-std/Test.sol";

import "src/GivPower.sol";

contract ContractTest is Test {
    // accounts
    address sender = address(1);
    address notAuthorized = address(2);

    bytes32 testScope =
        0x8c6753027d3e741bbfe01da77ac0b8feea667348cba07fad62f937782d475fdf;
    // upsertEntry(bytes32,bytes4,bytes)
    bytes4 testSig = bytes4(0xd3cd7efa);
    // QmWtGzMy7aNbMnLpmuNjKonoHc86mL1RyxqD2ghdQyq7Sm
    bytes testCID =
        "0x516d5774477a4d7937614e624d6e4c706d754e6a4b6f6e6f486338366d4c3152797871443267686451797137536d";

    function setUp() public {
        // rosetteStone = new GivPower();

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function testExample() public {
        assertTrue(true);
    }
}
