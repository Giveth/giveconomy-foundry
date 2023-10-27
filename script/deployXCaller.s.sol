// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import '../../contracts/GivethXCaller.sol';
import '../../contracts/GivethXReceiver.sol';
import '../../contracts/GIVbacksRelayer.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract deployRelayer is Script {
    using SafeMath for uint256;

    GivethXCaller givethXCallerImplementation;
    GivethXCaller givethXCaller;
    GIVbacksRelayer optimismGivbacksRelayer;
    TransparentUpgradeableProxy givethXcallerProxy;
    ProxyAdmin goerliProxyAdmin;

    address connextGoerli = 0xFCa08024A6D4bCc87275b1E4A1E22B71fAD7f649;
    address goerliTestETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    address optimismGoerliXReceiver = 0x35D3FeF295a14f7109C78487F516DA112ecF46bf;
    uint32 optimismGoerliDomainId = 1735356532;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        goerliProxyAdmin = new ProxyAdmin();
        givethXCallerImplementation = new GivethXCaller();
        givethXcallerProxy = new TransparentUpgradeableProxy(
                payable(address(givethXCallerImplementation)),
                address(goerliProxyAdmin),
                abi.encodeWithSelector(
                    GivethXCaller(givethXCaller).initialize.selector,
                    connextGoerli,
                    givethMultisig,
                    goerliTestETH
                )
            );
        givethXCaller = GivethXCaller(address(givethXcallerProxy));
        givethXCaller.addReceiver(optimismGoerliXReceiver, optimismGoerliDomainId, 'optimismGoerliReceiver');
        console.log('proxy admin', address(goerliProxyAdmin));
        console.log('giveth xcaller', address(givethXCaller));
        console.log('giveth xcaller implementation', address(givethXCallerImplementation));
    }
}
