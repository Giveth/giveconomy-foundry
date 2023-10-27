// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IConnext} from '@connext/interfaces/core/IConnext.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

contract GivethXCaller is Initializable, AccessControlEnumerableUpgradeable {
    IConnext public connext;
    bytes32 public CALLER_ROLE = keccak256('CALLER_ROLE');
    address public delegate;
    address private transferToken;

    event ReceiverAdded(uint256 index, string name, address indexed receiver, uint32 indexed domainId);
    event AddBatchesSent(address to, uint32 domainId, bytes callData);
    event MintNiceSent(address to, uint32 domainId, bytes callData);
    event ReceivedModified(uint256 index, address indexed receiver, uint32 indexed domainId);
    event AssetTokenSet(address indexed tokenAddress);
    event ConnextSet(address indexed connext);
    event DelegateSet(address indexed delegate);

    struct Receiver {
        address to;
        uint32 domainId;
    }

    Receiver[] public receivers;

    function initialize(address _connext, address _delegate, address _transferToken) public initializer {
        connext = IConnext(_connext);
        delegate = _delegate;
        transferToken = _transferToken;
        __AccessControlEnumerable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CALLER_ROLE, msg.sender);
    }

    function xAddBatches(uint256 receiverIndex, bytes calldata _callData, uint256 _relayerFee)
        external payable
        onlyRole(CALLER_ROLE)
    {
        connext.xcall{value: _relayerFee}(
            receivers[receiverIndex].domainId,
            receivers[receiverIndex].to,
            transferToken,
            delegate,
            0,
            3,
            _callData
        );
        emit AddBatchesSent(receivers[receiverIndex].to, receivers[receiverIndex].domainId, _callData);
    }

    function xMintNice(uint256 receiverIndex, bytes calldata _callData, uint256 _relayerFee)
        external payable
        onlyRole(CALLER_ROLE)
    {
        connext.xcall{value: _relayerFee}(
            receivers[receiverIndex].domainId,
            receivers[receiverIndex].to,
            transferToken,
            delegate,
            0,
            3,
            _callData    
        );
        emit MintNiceSent(receivers[receiverIndex].to, receivers[receiverIndex].domainId,_callData);
    }

    function addReceiver(address _to, uint32 _domainId, string memory receiverName)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        receivers.push(Receiver(_to, _domainId));
        emit ReceiverAdded(receivers.length - 1, receiverName, _to, _domainId);
    }

    function modifyReceiver(uint256 _index, address _to, uint32 _domainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        receivers[_index].to = _to;
        receivers[_index].domainId = _domainId;
        emit ReceivedModified(_index, _to, _domainId);
    }

    function getReceiverData(uint256 _index) external view returns (address, uint32) {
        return (receivers[_index].to, receivers[_index].domainId);
    }

    function setAssetToken(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferToken = tokenAddress;
        emit AssetTokenSet(tokenAddress);
    }

    function setConnect(address _connext) external onlyRole(DEFAULT_ADMIN_ROLE) {
        connext = IConnext(_connext);
        emit ConnextSet(_connext);
    }

    function setDelegate(address _delegate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delegate = _delegate;
        emit DelegateSet(_delegate);
    }
}
