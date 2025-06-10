// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'contracts/GIVbacksRelayer.sol';
import 'contracts/TokenDistro.sol';
import 'contracts/UnipoolGIVpower.sol';

contract deployRelayer is Script {
    GIVbacksRelayer givbacksRelayer;
    ProxyAdmin masterProxyAdmin;
    TokenDistro tokenDistro;
    UnipoolGIVpower unipoolGIVpower;

    // regular addresses & proxies
    address tokenDistroAddress = 0xE3Ac7b3e6B4065f4765d76fDC215606483BF3bD1;
    address masterProxyAdminAddress = 0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6;
    address givpowerAddress = 0x301C739CF6bfb6B47A74878BdEB13f92F13Ae5E7;
    address givbacksRelayerAddress = 0xf13e93aF5e706AB3073E393e77bb2d7ce7BEc01f;
    bytes32 adminRole = 0x0000000000000000000000000000000000000000000000000000000000000000;
    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;
    // implementation addresses
    address tokenDistroImplementationAddress = 0x95Fcf30706F3b1e28C8F3d72F4B80FA3A1615b2f;
    address unipoolGIVpowerImplementationAddress = 0x3b197F5cDa3516bD49e193df6F1273f3f16d414a;
    address givbacksRelayerImplementationAddress = 0x2AC383909Ff12F8a119220eEc16Dd081BB22f48E;
    address callerAddress = 0xe1ce7720f9b434ec98382f776e5C3A48C8BA6673;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);
        masterProxyAdmin = ProxyAdmin(masterProxyAdminAddress);
        tokenDistro = TokenDistro(tokenDistroAddress);
        unipoolGIVpower = UnipoolGIVpower(givpowerAddress);
        givbacksRelayer = GIVbacksRelayer(givbacksRelayerAddress);

        // give roles for givbacks relayer, token distro proxies
        tokenDistro.grantRole(adminRole, address(givethMultisig));
        givbacksRelayer.grantRole(adminRole, address(givethMultisig));
        // transfer ownership of proxy admin & givpower
        masterProxyAdmin.transferOwnership(address(givethMultisig));
        unipoolGIVpower.transferOwnership(address(givethMultisig));

        // give roles for givbacks relayer, token distro implementations
        // TokenDistro(tokenDistroImplementationAddress).grantRole(adminRole, address(givethMultisig));
        // GIVbacksRelayer(givbacksRelayerImplementationAddress).grantRole(adminRole, address(givethMultisig));
        // transfer ownership of givpower implementation
        // UnipoolGIVpower(unipoolGIVpowerImplementationAddress).transferOwnership(address(givethMultisig));

        // renounce admin role for token distro & givbacks relayer proxies
        tokenDistro.renounceRole(adminRole, address(callerAddress));
        givbacksRelayer.renounceRole(adminRole, address(callerAddress));
        // renoucne admin role for token distro & givbacks relayer implementations
        // TokenDistro(tokenDistroImplementationAddress).renounceRole(adminRole, address(this));
        // GIVbacksRelayer(givbacksRelayerImplementationAddress).renounceRole(adminRole, address(this));
    }
}
