// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/GIVbacksRelayer.sol';

contract deployRelayer is Script {
    GIVbacksRelayer implementation;
    GIVbacksRelayer givbacksRelayer;
    ProxyAdmin givbacksRelayerProxyAdmin;
    TransparentUpgradeableProxy givbacksRelayerProxy;
    IDistro iDistro;

    // token distro address
    address tokenDistro = 0x8D2cBce8ea0256bFFBa6fa4bf7CEC46a1d9b43f6;
    // admin of contract who is allowed to add batchers
    // address givethMultiSig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;
    address deployer = 0xe1ce7720f9b434ec98382f776e5C3A48C8BA6673;
    // address of initial batcher - should be agent or multisig who will be approving sending GIVbacks
    address batcher = 0x06263e1A856B36e073ba7a50D240123411501611;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        givbacksRelayerProxyAdmin = new ProxyAdmin();
        // new implementation
        implementation = new GIVbacksRelayer();
        givbacksRelayerProxy = new TransparentUpgradeableProxy(
            payable(address(implementation)),
            address(givbacksRelayerProxyAdmin),
            abi.encodeWithSelector(GIVbacksRelayer(givbacksRelayer).initialize.selector, tokenDistro, deployer, batcher)
        );
        givbacksRelayer = GIVbacksRelayer(address(givbacksRelayerProxy));

        console.log('proxy admin', address(givbacksRelayerProxyAdmin));
        console.log('givbacks relayer', address(givbacksRelayer));
        console.log('givbacks relayer implementation', address(implementation));
    }
}
