// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import '../../contracts/GivethXCaller.sol';
import '../../contracts/GivethXReceiver.sol';
import '../../contracts/GIVbacksRelayer.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

interface Agent {
    function execute(address _target, uint256 _ethValue, bytes memory _data)
        external
        payable
        returns (bytes memory response);
}

interface ACL {
    function grantPermission(address _entity, address _app, bytes32 _role) external;
}

contract XCallerTest is Test {
    using SafeMath for uint256;

    uint256 optimismGoerliFork = vm.createFork('https://goerli.optimism.io/');
    address connextOptimismGoerli = 0x5Ea1bb242326044699C3d81341c5f535d5Af1504;
    address originAddress = 0x53EC1a992a00015751CfC71E7b1395972d762Cf8;
    uint32 goerliDomainId = 1735353714;
    GivethXReceiver givethReceiver = GivethXReceiver(0xC2CAfef7809aE0e37c62F9dE9B15F11975567Ea8);
    GIVbacksRelayer givbacksRelayer = GIVbacksRelayer(0x3e2C98F1Fd45481F391005F259BC85ccE12F87D1);

    constructor() {}

    function setup() public {
        vm.selectFork(optimismGoerliFork);

    }

    function testXreceive() public {
         address[] memory recipients = new address[](3);
        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);

        uint256 one = 1;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = one.mul(10 ** 18);
        amounts[1] = one.mul(10 ** 18);
        amounts[2] = one.mul(10 ** 18);

        // hash batches of dummy data
        bytes32 batchData1 = givbacksRelayer.hashBatch(1, recipients, amounts);
        bytes32 batchData2 = givbacksRelayer.hashBatch(2, recipients, amounts);

        // ABI of the function addBatches
        bytes4 ADD_BATCHES_SELECTOR = bytes4(keccak256('addBatches(bytes32[],bytes)'));

        // Encode the function call
        bytes memory data = abi.encodeWithSelector(
            ADD_BATCHES_SELECTOR,
            [batchData1, batchData2], // bytes32[] calldata batches
            'QmbZTCU7W7h31NsQK9KncsDQorBLYbNmDuYGn7VMme8wH1' // bytes calldata ipfsData
        );
        vm.prank(connextOptimismGoerli);
        givethReceiver.xReceive(
            0x7550b8c181f484478bb16b546e2fe44736a0f899574c600a1230374d4a7b49ac,
            0,
            address(0),
            originAddress,
            goerliDomainId,
            data
        );
        

    }
}