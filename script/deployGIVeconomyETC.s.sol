// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/TokenDistro.sol';
import 'contracts/tokens/etcGIV.sol';

contract deployTokenDistro is Script {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ProxyAdmin proxyAdmin;
    TokenDistro tokenDistroImplementation;
    TokenDistro tokenDistro;
    TransparentUpgradeableProxy tokenDistroProxy;

    GivethToken givethToken;
    TransparentUpgradeableProxy givethTokenProxy;
    GivethToken givethTokenImplementation;

    // initiliaze params for token distro
    uint256 totalTokens = 2000000000000000000000000000;
    // 1 million tokens to mint and send to token Distro
    uint256 initialTokens = 1000000;
    // same as GIV on mainnet - Dec 24 2021
    uint256 startTime = 1640361600;
    uint256 cliffPeriod = 0;
    // duration of 5 years in seconds
    uint256 duration = 157680000;
    // starting percentage at 10%
    uint256 initialPercentage = 1000;
    bool cancelable = true;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
        vm.startBroadcast(deployerPrivateKey);
        // deploy proxy admin contracts (controls upgrade functions)
        proxyAdmin = new ProxyAdmin();
        // deploy giv token implementation contract
        givethTokenImplementation = new GivethToken();
        // deploy giv token proxy contract based off implementation
        givethTokenProxy =
        new TransparentUpgradeableProxy(payable(address(givethTokenImplementation)), address(proxyAdmin),
         abi.encodeWithSelector(GivethToken(givethToken).initialize.selector, msg.sender, msg.sender));
        // alias givethToken to the proxy contract
        givethToken = GivethToken(address(givethTokenProxy));

        // new tokenDistroImplementation
        // deploy implementation contract of token distro
        tokenDistroImplementation = new TokenDistro();
        // deploy proxy contract of token distro based off implementation
        tokenDistroProxy =
        new TransparentUpgradeableProxy(payable(address(tokenDistroImplementation)), address(proxyAdmin),
         abi.encodeWithSelector(TokenDistro(tokenDistro).initialize.selector, totalTokens, startTime, cliffPeriod, duration, initialPercentage, givethToken, cancelable));
        // alias tokenDistro to the proxy contract
        tokenDistro = TokenDistro(address(tokenDistroProxy));

        // log addresses to console on script run
        console.log('proxy admin', address(proxyAdmin));
        console.log('token distro', address(tokenDistro));
        console.log('token distro tokenDistroImplementation', address(tokenDistroImplementation));
        console.log('giv token addres', address(givethToken));

        // mint GIV tokens to token Distro
        givethToken.mint(address(tokenDistro), initialTokens);
    }
}
