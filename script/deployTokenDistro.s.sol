// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/TokenDistro.sol';

contract deployTokenDistro is Script {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    TokenDistro implementation;
    TokenDistro tokenDistro;
    ProxyAdmin tokenDistroProxyAdmin;
    TransparentUpgradeableProxy tokenDistroProxy;

    // token
    address givTokenAddressOptimismGoerli = 0xc916Ce4025Cb479d9BA9D798A80094a449667F5D;
    address givTokenOptimismMainnet = 0x528CDc92eAB044E1E39FE43B9514bfdAB4412B98;

    // initiliaze params for token distro
    uint256 totalTokens = 2000000000000000000000000000;
    uint256 startTime = 1640361600; 
    uint256 cliffPeriod = 0;
    uint256 duration = 157680000;
    uint256 initialPercentage = 1000;
    IERC20Upgradeable givToken = IERC20Upgradeable(givTokenOptimismMainnet);
    bool cancelable = true;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
        
        vm.startBroadcast(deployerPrivateKey);
        tokenDistroProxyAdmin = new ProxyAdmin();
        // new implementation
        implementation = new TokenDistro();
        tokenDistroProxy =
        new TransparentUpgradeableProxy(payable(address(implementation)), address(tokenDistroProxyAdmin),
         abi.encodeWithSelector(TokenDistro(tokenDistro).initialize.selector, totalTokens, startTime, cliffPeriod, duration, initialPercentage, givToken, cancelable));
        tokenDistro = TokenDistro(address(tokenDistroProxy));

        console.log('proxy admin' , address(tokenDistroProxyAdmin));
        console.log('token distro', address(tokenDistro));
        console.log('token distro implementation', address(implementation));

    }
}