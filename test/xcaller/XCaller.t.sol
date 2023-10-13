
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import '../../contracts/GivethXCaller.sol';
import '../../contracts/GivethXReceiver.sol';
import "aragon-apps/agent/contracts/Agent.sol";
import "../../contracts/GIVbacksRelayer.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";




contract XCallerTest is Test {
        using SafeMath for uint256;
    constructor() {
        uint256 forkId = vm.createFork('https://mainnet.optimism.io/', 110809941);
        vm.selectFork(forkId);
    }
    Agent aragonAgent = Agent(0xb99aae15ace6509930760f1bde96c60542d2c0c1);
    GivethXCaller givethXCallerImplementation;
    GivethXCaller givethXCaller;
    GIVbacksRelayer givbacksRelayer;
    TransparentUpgradeableProxy givethXcallerProxy;
    ProxyAdmin proxyAdmin = ProxyAdmin(0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6);

    address connextOptimism = 0x8f7492DE823025b4CfaAB1D34c58963F2af5DEDA;
    uint32 optimismDomainId = 1869640809;

    address connextGnosis = 0x5bB83e95f63217CDa6aE3D181BA580Ef377D2109;
    uint32 gnosisDomainId = 6778479;
    address gnosisReceiver = address(4);

    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    function setUp() public {
        givethXCallerImplementation = new GivethXCaller();
        givbacksRelayer = new GIVbacksRelayer();
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
        givethXCaller.grantRole(givethXCaller.CALLER_ROLE(), address(aragonAgent));
        givethXCaller.addReceiver(
            gnosisReceiver,
            gnosisDomainId,
            'gnosisReceiver'
        );

        console.log('proxy admin', address(proxyAdmin));
        console.log('givethXCaller', address(givethXCaller));
        console.log('givethXCaller implementation', address(givethXCallerImplementation));

        vm.label(address(givethXCaller), 'givethXCaller');
        vm.label(address(givethXCallerImplementation), 'givethXCallerImplementation');
        vm.label(address(givethXcallerProxy), 'givethXcallerProxy');
        vm.label(address(proxyAdmin), 'proxyAdmin');
        vm.label(address(connextOptimism), 'connextOptimism');
        vm.label(address(givethMultisig), 'givethMultisig');
        vm.label(address(aragonAgent), 'aragonAgent');
    }

    function testCall() public {
        address[] memory recipients = new address[](3);
        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);

        uint256 one = 1;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = one.mul(10**18);
        amounts[1] = one.mul(10**18);
        amounts[2] = one.mul(10**18);

        // ABI of the function addBatches
        bytes4 private constant ADD_BATCHES_SELECTOR = bytes4(keccak256("addBatches(bytes32[],bytes)"));

        // Encode the function call
        bytes memory data = abi.encodeWithSelector(
            ADD_BATCHES_SELECTOR,
            [batchData1, batchData2],   // bytes32[] calldata batches
            'QmbZTCU7W7h31NsQK9KncsDQorBLYbNmDuYGn7VMme8wH1'  // bytes calldata ipfsData
        );

        bytes32 batchData1 = givbacksRelayer.hashBatch(1, recipients, amounts);
        bytes32 batchData2 = givbacksRelayer.hashBatch(2, recipients, amounts);

        aragonAgent.execute(abi.encodeWithSelector(GivethXCaller(givethXCaller).xAddBatches.selector, 1, data));

}

}