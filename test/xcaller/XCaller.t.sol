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

    uint256 optimismFork = vm.createFork('https://mainnet.optimism.io/');
    uint256 gnosisFork = vm.createFork('https://rpc.ankr.com/gnosis'); //https://xdai-archive.blockscout.com/

    constructor() {}

    // optimism givbacks DAO app addresses
    Agent aragonAgent = Agent(0xB99Aae15ACE6509930760f1bde96c60542d2c0c1);
    ACL acl = ACL(0xCdAE371A746ebcce5159357C7D3B6f24aF62fEC0);

    //  xcaller proxy contract names
    GivethXCaller givethXCallerImplementation;
    GivethXCaller givethXCaller;
    GIVbacksRelayer optimismGivbacksRelayer;
    TransparentUpgradeableProxy givethXcallerProxy;
    ProxyAdmin optimismProxyAdmin = ProxyAdmin(0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6);
    address voting = 0x0509104664e55d657E410AbF049854F31f49b9A6;

    //xreceiver proxy contract names
    GivethXReceiver givethXReceiverImplementation;
    GivethXReceiver givethXReceiver;
    GIVbacksRelayer gnosisGivbacksRelayer;
    TransparentUpgradeableProxy givethXReceiverProxy;
    ProxyAdmin gnosisProxyAdmin = ProxyAdmin(0x076C250700D210e6cf8A27D1EB1Fd754FB487986);

    // connext variables & contracts optimism
    address connextOptimism = 0x8f7492DE823025b4CfaAB1D34c58963F2af5DEDA;
    uint32 optimismDomainId = 1869640809;
    // connext variables & contracts gnosis
    address connextGnosis = 0x5bB83e95f63217CDa6aE3D181BA580Ef377D2109;
    uint32 gnosisDomainId = 6778479;

    // dummmy receiver address - need to change to actual receiver
    address gnosisReceiver = address(4);

    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    function setUp() public {
        vm.selectFork(optimismFork);
        // grant permission to deployed x call to execute
        // vm.prank(voting);
        // acl.grantPermission(address(givethXCaller), address(aragonAgent), keccak256("EXECUTE_ROLE"));

        // deploy x caller contract
        givethXCallerImplementation = new GivethXCaller();
        optimismGivbacksRelayer = new GIVbacksRelayer();
        givethXcallerProxy = new TransparentUpgradeableProxy(
            payable(address(givethXCallerImplementation)),
            address(optimismProxyAdmin),
            abi.encodeWithSelector(
                GivethXCaller(givethXCaller).initialize.selector,
                connextOptimism,
                givethMultisig
            )
        );
        givethXCaller = GivethXCaller(address(givethXcallerProxy));

        // grant permission to aragon agent on optimism givbacks dao to call x caller
        givethXCaller.grantRole(givethXCaller.CALLER_ROLE(), address(aragonAgent));

        // add receiver for gnosis to x caller
        givethXCaller.addReceiver(gnosisReceiver, gnosisDomainId, 'gnosisReceiver');

        // log deployed contract addresses
        console.log('proxy admin', address(optimismProxyAdmin));
        console.log('givethXCaller', address(givethXCaller));
        console.log('givethXCaller implementation', address(givethXCallerImplementation));

        (string memory name, address receiver, uint32 domainId) = givethXCaller.getReceiverData(0);
        console.log('receiver name', name);
        console.log('receiver address', receiver);
        console.log('receiver domainId', domainId);

        //gnosis deployment
        vm.selectFork(gnosisFork);

        givethXReceiverImplementation = new GivethXReceiver();
        gnosisGivbacksRelayer = new GIVbacksRelayer();
        givethXReceiverProxy = new TransparentUpgradeableProxy(
            payable(address(givethXReceiverImplementation)),
            address(gnosisProxyAdmin),
            abi.encodeWithSelector(
                GivethXReceiver(givethXReceiver).initialize.selector,
                connextGnosis,
                address(givethXReceiver),
                optimismDomainId,
                address(gnosisGivbacksRelayer)
            )
        );
        givethXReceiver = GivethXReceiver(address(givethXReceiverProxy));

        // log deployed contract addresses
        console.log('proxy admin', address(gnosisProxyAdmin));
        console.log('givethXReceiver', address(givethXReceiver));
        console.log('givethXReceiver implementation', address(givethXReceiverImplementation));

        // add labels
        vm.label(address(givethXCaller), 'givethXCaller');
        vm.label(address(givethXCallerImplementation), 'givethXCallerImplementation');
        vm.label(address(givethXcallerProxy), 'givethXcallerProxy');
        vm.label(address(optimismProxyAdmin), 'optimismProxyAdmin');
        vm.label(address(connextOptimism), 'connextOptimism');
        vm.label(address(givethMultisig), 'givethMultisig');
        vm.label(address(aragonAgent), 'aragonAgent');
        vm.label(0x745837468A6A4f7EF5eB3fEE18fc6E74376443C6, 'bridge facet');
        vm.label(address(optimismGivbacksRelayer), 'optimismGivbacksRelayer');
        vm.label(address(gnosisGivbacksRelayer), 'gnosisGivbacksRelayer');
        vm.label(address(givethXReceiver), 'givethXReceiver');
        vm.label(address(givethXReceiverImplementation), 'givethXReceiverImplementation');
        vm.label(address(givethXReceiverProxy), 'givethXReceiverProxy');
        vm.label(address(gnosisProxyAdmin), 'gnosisProxyAdmin');
        vm.label(address(connextGnosis), 'connextGnosis');
    }

    function testCall() public {
        vm.selectFork(optimismFork);
        // create dummy distribution data
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
        bytes32 batchData1 = optimismGivbacksRelayer.hashBatch(1, recipients, amounts);
        bytes32 batchData2 = optimismGivbacksRelayer.hashBatch(2, recipients, amounts);

        // ABI of the function addBatches
        bytes4 ADD_BATCHES_SELECTOR = bytes4(keccak256('addBatches(bytes32[],bytes)'));

        // Encode the function call
        bytes memory data = abi.encodeWithSelector(
            ADD_BATCHES_SELECTOR,
            [batchData1, batchData2], // bytes32[] calldata batches
            'QmbZTCU7W7h31NsQK9KncsDQorBLYbNmDuYGn7VMme8wH1' // bytes calldata ipfsData
        );

        // execute the call via aragon agent from voting app that has execute permission on agent
        vm.prank(voting);
        aragonAgent.execute(
            address(givethXCaller),
            0,
            abi.encodeWithSelector(GivethXCaller(givethXCaller).xAddBatches.selector, 0, data)
        );
    }
}
