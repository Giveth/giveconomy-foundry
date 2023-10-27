// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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
    //xreceiver proxy contract names

    GivethXReceiver givethXReceiverImplementation;
    GivethXReceiver givethXReceiver;
    GIVbacksRelayer gnosisGivbacksRelayer;
    TransparentUpgradeableProxy givethXReceiverProxy;
    ProxyAdmin goerliProxyAdmin;

    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    // optimism goerli address
    address connextOptimismGoerli = 0x5Ea1bb242326044699C3d81341c5f535d5Af1504;
    uint256 domainIdOptimismGoerli = 1735356532;
    address givbacksRelayerOptimismGoerli = 0x3e2C98F1Fd45481F391005F259BC85ccE12F87D1;
    // goerli addresses
    address xCallerGoerli = 0x53EC1a992a00015751CfC71E7b1395972d762Cf8;
    uint256 domainIdGoerli = 1735353714;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        goerliProxyAdmin = new ProxyAdmin();
        givethXReceiverImplementation = new GivethXReceiver();
        givethXReceiverProxy = new TransparentUpgradeableProxy(
                payable(address(givethXReceiverImplementation)),
                address(goerliProxyAdmin),
                abi.encodeWithSelector(
                    GivethXReceiver(givethXReceiver).initialize.selector,
                    connextOptimismGoerli,
                    xCallerGoerli,
                    domainIdGoerli,
                    givbacksRelayerOptimismGoerli
                )
            );
        givethXReceiver = GivethXReceiver(address(givethXReceiverProxy));

        console.log('proxy admin', address(goerliProxyAdmin));
        console.log('giveth xreceiver', address(givethXReceiver));
        console.log('giveth xreceiver implementation', address(givethXReceiverImplementation));
    }
}
