// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

// Based on: https://github.com/1Hive/token-manager-app/blob/master/contracts/TokenManagerHook.sol
/*
 * changelog:
 *      * Add Initialize function
 *      * Token manager is set in the initialization function
 *      * `onRegisterAsHook` now has the `onlyTokenManager` modifier and do not update the token manager
 */

library UnstructuredStorage {
    function getStorageBool(bytes32 position) internal view returns (bool data) {
        assembly {
            data := sload(position)
        }
    }

    function getStorageAddress(bytes32 position) internal view returns (address data) {
        assembly {
            data := sload(position)
        }
    }

    function getStorageBytes32(bytes32 position) internal view returns (bytes32 data) {
        assembly {
            data := sload(position)
        }
    }

    function getStorageUint256(bytes32 position) internal view returns (uint256 data) {
        assembly {
            data := sload(position)
        }
    }

    function setStorageBool(bytes32 position, bool data) internal {
        assembly {
            sstore(position, data)
        }
    }

    function setStorageAddress(bytes32 position, address data) internal {
        assembly {
            sstore(position, data)
        }
    }

    function setStorageBytes32(bytes32 position, bytes32 data) internal {
        assembly {
            sstore(position, data)
        }
    }

    function setStorageUint256(bytes32 position, uint256 data) internal {
        assembly {
            sstore(position, data)
        }
    }
}

contract ReentrancyGuard {
    using UnstructuredStorage for bytes32;

    /* Hardcoded constants to save gas
    bytes32 internal constant REENTRANCY_MUTEX_POSITION = keccak256("aragonOS.reentrancyGuard.mutex");
    */
    bytes32 private constant REENTRANCY_MUTEX_POSITION =
        0xe855346402235fdd185c890e68d2c4ecad599b88587635ee285bce2fda58dacb;

    string private constant ERROR_REENTRANT = 'REENTRANCY_REENTRANT_CALL';

    modifier nonReentrant() {
        // Ensure mutex is unlocked
        require(!REENTRANCY_MUTEX_POSITION.getStorageBool(), ERROR_REENTRANT);

        // Lock mutex before function call
        REENTRANCY_MUTEX_POSITION.setStorageBool(true);

        // Perform function call
        _;

        // Unlock mutex after function call
        REENTRANCY_MUTEX_POSITION.setStorageBool(false);
    }
}

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

/**
 * @dev When creating a subcontract, we recommend overriding the _internal_ functions that you want to hook.
 */
contract TokenManagerHook is ReentrancyGuard, Initializable {
    using UnstructuredStorage for bytes32;

    /* Hardcoded constants to save gas
    bytes32 public constant TOKEN_MANAGER_POSITION = keccak256("hookedTokenManager.tokenManagerHook.tokenManager");
    */
    bytes32 private constant TOKEN_MANAGER_POSITION = 0x5c513b2347f66d33af9d68f4a0ed7fbb73ce364889b2af7f3ee5764440da6a8a;

    modifier onlyTokenManager() {
        require(getTokenManager() == msg.sender, 'Hooks must be called from Token Manager');
        _;
    }

    /**
     * @dev Usually this contract is deploy by a factory, and in the same transaction, `onRegisterAsHook` is called.
     * Since in this case, the `onRegisterAsHook` will be called after the deployment, to avoid unwanted calls to `onRegisterAsHook`,
     * token manager address is set in the initialization.
     * @param tokenManager Token manager address
     */
    function __TokenManagerHook_initialize(address tokenManager) public initializer {
        TOKEN_MANAGER_POSITION.setStorageAddress(tokenManager);
    }

    function getTokenManager() public view returns (address) {
        return TOKEN_MANAGER_POSITION.getStorageAddress();
    }

    /*
     * @dev Called when this contract has been included as a Token Manager hook, must be called in the transaction
     *   this contract is created or it risks some other address registering itself as the Token Manager
     * @param _hookId The position in which the hook is going to be called
     * @param _token The token controlled by the Token Manager
     */
    function onRegisterAsHook(uint256 _hookId, address _token) external nonReentrant onlyTokenManager {
        _onRegisterAsHook(msg.sender, _hookId, _token);
    }

    /*
     * @dev Called when this hook is being removed from the Token Manager
     * @param _hookId The position in which the hook is going to be called
     * @param _token The token controlled by the Token Manager
     */
    function onRevokeAsHook(uint256 _hookId, address _token) external onlyTokenManager nonReentrant {
        _onRevokeAsHook(msg.sender, _hookId, _token);
    }

    /*
     * @dev Notifies the hook about a token transfer allowing the hook to react if desired. It should return
     * true if left unimplemented, otherwise it will prevent some functions in the TokenManager from
     * executing successfully.
     * @param _from The origin of the transfer
     * @param _to The destination of the transfer
     * @param _amount The amount of the transfer
     */
    function onTransfer(address _from, address _to, uint256 _amount)
        external
        onlyTokenManager
        nonReentrant
        returns (bool)
    {
        return _onTransfer(_from, _to, _amount);
    }

    /*
     * @dev Notifies the hook about an approval allowing the hook to react if desired. It should return
     * true if left unimplemented, otherwise it will prevent some functions in the TokenManager from
     * executing successfully.
     * @param _holder The account that is allowing to spend
     * @param _spender The account that is allowed to spend
     * @param _amount The amount being allowed
     */
    function onApprove(address _holder, address _spender, uint256 _amount)
        external
        onlyTokenManager
        nonReentrant
        returns (bool)
    {
        return _onApprove(_holder, _spender, _amount);
    }

    // Function to override if necessary:

    function _onRegisterAsHook(address, /* _tokenManager*/ uint256, /* _hookId*/ address /* _token*/ )
        internal
        virtual
    {
        return;
    }

    function _onRevokeAsHook(address, /* _tokenManager*/ uint256, /* _hookId*/ address /* _token*/ ) internal virtual {
        return;
    }

    function _onTransfer(address, /* _from*/ address, /* _to*/ uint256 /* _amount*/ ) internal virtual returns (bool) {
        return true;
    }

    function _onApprove(address, /* _holder*/ address, /* _spender*/ uint256 /* _amount*/ )
        internal
        virtual
        returns (bool)
    {
        return true;
    }
}