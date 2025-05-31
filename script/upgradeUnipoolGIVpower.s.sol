// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import '../contracts/UnipoolGIVpower.sol';
import '../contracts/interfaces/IDistro.sol';


contract UpgradeUnipoolGIVpower is Script {
/// @notice Op Sepolia addresses
address proxyAdminOpSepoliaAddress = 0x3b197F5cDa3516bD49e193df6F1273f3f16d414a;
address unipoolProxyOpSepoliaAddress = 0xE6836325B13819CF38f030108255A5213491A725;
address iDistroOpSepoliaAddress = 0x301C739CF6bfb6B47A74878BdEB13f92F13Ae5E7;
    
    ProxyAdmin unipoolProxyAdmin;
    ITransparentUpgradeableProxy unipoolProxy;
    UnipoolGIVpower implementation;
    UnipoolGIVpower givpower;
    IDistro iDistro;

    function run() public {
        unipoolProxyAdmin = ProxyAdmin(proxyAdminOpSepoliaAddress);
        iDistro = IDistro(iDistroOpSepoliaAddress);
        unipoolProxy = ITransparentUpgradeableProxy(payable(unipoolProxyOpSepoliaAddress));
        givpower = UnipoolGIVpower(address(unipoolProxy));
        // new implementation

        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        implementation = new UnipoolGIVpower();

        unipoolProxyAdmin.upgrade(unipoolProxy, address(implementation));

        vm.stopBroadcast();

        console.log('new implementation address: ', address(implementation));
    }
}
