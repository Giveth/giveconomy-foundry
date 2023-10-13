// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IXReceiver} from "@connext/interfaces/core/IXReceiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract GivethXReceiver is Initializable, OwnableUpgradeable {

    address public connext;
    address public callerAddress;
    uint32 public callerDomainId;
    address public target;
    event GivbacksRelayerSet(address indexed target);
    event ForwardedCall(address target, bytes callData);

    function initialize(address _connext, address _callerAddress, uint32 _callerDomainId, address _target) public initializer {
        connext = _connext;
        callerAddress = _callerAddress;
        callerDomainId = _callerDomainId;
        target = _target;
        __Ownable_init();
    }

    modifier onlySource(address _originSender, uint32 _originDomain) {
        require(msg.sender == connext && _originSender == callerAddress && _originDomain == callerDomainId, "GivethXCaller: only source");
        _;
    }

    function xReceive(
    bytes32 _transferId,
    uint256 _amount,
    address _asset,
    address _originSender,
    uint32 _origin,
    bytes memory _callData
  ) external onlySource(_originSender, _origin) returns ( bool) {
    // Unpack the _callData
    (bool success, ) = target.call(_callData);
    require(success, "Call to target contract failed");
    emit ForwardedCall(target, _callData);
    return true;
  }

  function setCallerAddress(address _callerAddress) external onlyOwner {
      callerAddress = _callerAddress;
  }

    function setCallerDomainId(uint32 _callerDomainId) external onlyOwner {
        callerDomainId = _callerDomainId;
    }   
    function setGivbacksRelayer(address _target) external onlyOwner {
        target = _target;
    }

}