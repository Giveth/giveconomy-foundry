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

    // goerli contracts deployed
    GIVbacksRelayer goerliGIVbacksRelayer = GIVbacksRelayer(0xDEA9Ac7FfE99E3dDD1Bd60FDf9B044e0E22471b8);
    GivethXCaller givethXCaller = GivethXCaller(0x066c98d891F35357880bA36fbc5d67b909C29634);

    // optimism addresses
    uint32 domainIdOptimismGoerli = 1735356532;
    address optimismGoerliReceiver = 0xC2CAfef7809aE0e37c62F9dE9B15F11975567Ea8;

    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

        vm.startBroadcast(deployerPrivateKey);

        address[] memory recipients = new address[](3);
        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 1e18;

        // hash batches of dummy data
        bytes32 batchData1 = goerliGIVbacksRelayer.hashBatch(0, recipients, amounts);
        bytes32 batchData2 = goerliGIVbacksRelayer.hashBatch(1, recipients, amounts);

        // ABI of the function addBatches
        bytes4 ADD_BATCHES_SELECTOR = bytes4(keccak256('addBatches(bytes32[],bytes)'));

        bytes32[] memory batches = new bytes32[](2);
        batches[0] = batchData1;
        batches[1] = batchData2;

        bytes memory ipfsData = abi.encodePacked('QmbZTCU7W7h31NsQK9KncsDQorBLYbNmDuYGn7VMme8wH1');
        // Encode the function call
        bytes memory data = abi.encodeWithSelector(
            ADD_BATCHES_SELECTOR,
            batches, // bytes32[] calldata batches
            ipfsData // bytes calldata ipfsData
        );

        console.logBytes(data);

        givethXCaller.xAddBatches{value: 0.01 ether}(0, data, 0.01 ether);
    }
}
