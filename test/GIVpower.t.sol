// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/Test.sol";

import "src/GIVpower.sol";

contract GIVpowerTest is Test {
    ProxyAdmin gardenUnipoolProxyAdmin;
    TransparentUpgradeableProxy gardenUnipool;
    GIVpower implementation;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);

    function setUp() public {
        gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));

        gardenUnipool = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));

        // new implementation
        implementation = new GIVpower();

        vm.prank(gardenUnipoolProxyAdmin.owner());
        gardenUnipoolProxyAdmin.upgrade(gardenUnipool, address(implementation));

        // labels
        vm.label(sender, "sender");
        vm.label(notAuthorized, "notAuthorizedAddress");
    }

    function testExample() public {
        assertTrue(true);
    }
}
