
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import '../../contracts/GivethXCaller.sol';
import '../../contracts/GivethXReceiver.sol';

contract XCallerTest is Test {
    constructor() {
        uint256 forkId = vm.createFork('https://mainnet.optimism.io/', 110809941);
        vm.selectFork(forkId);
    }

    address aragonAgent = address(1);
    GivethXCaller givethXCallerImplementation;
    GivethXCaller givethXCaller;
    TransparentUpgradeableProxy givethXcallerProxy;
    ProxyAdmin proxyAdmin = ProxyAdmin(0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6);
    address connextOptimism = 0x8f7492DE823025b4CfaAB1D34c58963F2af5DEDA;
    uint32 domainId = 1869640809;
    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    function setUp() public {
        givethXCallerImplementation = new GivethXCaller();
        givethXcallerProxy = new TransparentUpgradeableProxy(
            payable(address(givethXCallerImplementation)),
            address(proxyAdmin),
            abi.encodeWithSelector(
                GivethXCaller(givethXCaller).initialize.selector,
                connextOptimism,
                givethMultisig
            )
        );
        givethXCaller = GivethXCaller(address(givethXcallerProxy));
        givethXCaller.grantRole(givethXCaller.CALLER_ROLE(), aragonAgent);

        console.log('proxy admin', address(proxyAdmin));
        console.log('givethXCaller', address(givethXCaller));
        console.log('givethXCaller implementation', address(givethXCallerImplementation));

        vm.label(address(givethXCaller), 'givethXCaller');
        vm.label(address(givethXCallerImplementation), 'givethXCallerImplementation');
        vm.label(address(givethXcallerProxy), 'givethXcallerProxy');
        vm.label(address(proxyAdmin), 'proxyAdmin');
        vm.label(address(connextOptimism), 'connextOptimism');
        vm.label(address(givethMultisig), 'givethMultisig');
        vm.label(aragonAgent, 'aragonAgent');
    }
}

