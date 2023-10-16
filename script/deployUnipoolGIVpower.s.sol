// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/UnipoolGIVpower.sol';

contract deployUnipoolGIVpower is Script {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    UnipoolGIVpower implementation;
    UnipoolGIVpower givPower;
    ProxyAdmin unipoolGIVpowerProxyAdmin;
    TransparentUpgradeableProxy unipoolGIVpowerProxy;
    IERC20Upgradeable givToken;
    IDistro iDistro;

    // token
    // address givTokenAddressOptimismGoerli = 0xc916Ce4025Cb479d9BA9D798A80094a449667F5D;
    address givTokenAddressOptimismMainnet = 0x528CDc92eAB044E1E39FE43B9514bfdAB4412B98;
    address tokenDistroOptimismMainnet = 0xE3Ac7b3e6B4065f4765d76fDC215606483BF3bD1;
    address tokenDistroOptimismGoerli = 0x8D2cBce8ea0256bFFBa6fa4bf7CEC46a1d9b43f6;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        // givToken = IERC20Upgradeable(givTokenAddressOptimismMainnet);
        // iDistro = IDistro(tokenDistroOptimismMainnet);
        // unipoolGIVpowerProxyAdmin = new ProxyAdmin();
        // new implementation
        implementation = new UnipoolGIVpower();
        // unipoolGIVpowerProxy =
        // new TransparentUpgradeableProxy(payable(address(implementation)), address(unipoolGIVpowerProxyAdmin),
        //  abi.encodeWithSelector(UnipoolGIVpower(givPower).initialize.selector, iDistro, givToken, 14 days));
        // givPower = UnipoolGIVpower(address(unipoolGIVpowerProxy));

        // console.log('unipoolproxyadmin' , address(unipoolGIVpowerProxyAdmin));
        // console.log('givpower', address(givPower));
        console.log('givpower implementation', address(implementation));
    }
}
