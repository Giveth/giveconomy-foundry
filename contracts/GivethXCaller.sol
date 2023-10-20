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

    event ReceiverAdded(uint256 index, string name);
    event AddBatchesSent(bytes callData);
    event MintNiceSent(bytes callData);


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

    function xAddBatches(uint256 receiverIndex, bytes calldata _callData, uint256 _relayerFee) external onlyRole(CALLER_ROLE) {
        connext.xcall(
            receivers[receiverIndex].domainId, receivers[receiverIndex].to, address(0x00), delegate, 0, 3, _callData, _relayerFee
        );
        emit AddBatchesSent(_callData);
    }

    function xMintNice(uint256 receiverIndex, bytes calldata _callData, uint256 _relayerFee) external onlyRole(CALLER_ROLE) {
        connext.xcall(
            receivers[receiverIndex].domainId, receivers[receiverIndex].to, transferToken, delegate, 0, 3, _callData, _relayerFee
        );
        emit MintNiceSent(_callData);
    }

    function addReceiver(address _to, uint32 _domainId, string memory receiverName)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        receivers.push(Receiver(_to, _domainId));
        emit ReceiverAdded(receivers.length - 1, receiverName);
    }

    function modifyReceiver(uint256 _index, address _to, uint32 _domainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        receivers[_index].to = _to;
        receivers[_index].domainId = _domainId;
    }

    function getReceiverData(uint256 _index) external view returns (address, uint32) {
        return ( receivers[_index].to, receivers[_index].domainId);
    }

    function setAssetToken(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferToken = tokenAddress;
    }
}
