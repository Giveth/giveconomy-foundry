// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ExampleRegistry is Ownable {
    string public message;

    event MessageChanged(string message, address admin);

    function setMessage(string calldata _message) external onlyOwner {
        message = _message;
        emit MessageChanged(_message, msg.sender);
    }
}
