// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import '@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import './interfaces/IGIVBacksRelayer.sol';
import './interfaces/IDistro.sol';

contract GIVbacksRelayer is Initializable, AccessControlEnumerableUpgradeable, IGIVBacksRelayer {
    ///
    /// CONSTANTS:
    ///

    /// @dev BATCHER_ROLE = keccak256("BATCHER_ROLE");
    bytes32 public constant BATCHER_ROLE = 0xeccb356c360bf90186ea17a138ef77420582d0f2a31f7c029d6ae4c3a7c2e186;

    ///
    /// STORAGE:
    ///

    /// @dev This mapping marks all unexecuted batches as `true`
    mapping(bytes32 => bool) internal pendingBatches;

    /// @dev The address of the TokenDistro contract
    address public tokenDistroContract;

    /// @dev The last nonce generated by `addBatch`
    uint256 public nonce;

    ///
    /// MODIFIERS:
    ///

    /// @dev Revert if not called by `BATCHER_ROLE`
    modifier onlyBatcher() {
        require(hasRole(BATCHER_ROLE, msg.sender), 'GIVBacksRelayer::onlyBatcher: MUST_BATCHER');
        _;
    }

    /**
     * @dev Initialize the relayer.
     * The deployer address is set as the `DEFAULT_ADMIN_ROLE`. It can add new
     * batchers if it's required.
     *
     * @param _tokenDistroContract - The address of the TokenDistro
     * @param batcher - Initial batcher address
     */
    function initialize(address _tokenDistroContract, address batcher, address batcherRoleAdmin) public initializer {
        require(_tokenDistroContract != address(0), 'GIVBacksRelayer::initialize: NO_TOKENDISTRO_ZERO_ADDRESS');
        require(batcher != address(0), 'GIVBacksRelayer::initialize: NO_BATCHER_ZERO_ADDRESS');

        tokenDistroContract = _tokenDistroContract;

        __AccessControlEnumerable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, batcherRoleAdmin);
        _setupRole(BATCHER_ROLE, batcher);
    }

    /// @inheritdoc IGIVBacksRelayer
    function addBatch(bytes32 batch, bytes calldata ipfsData) external override onlyBatcher {
        _addBatch(batch, ipfsData);
    }

    /// @inheritdoc IGIVBacksRelayer
    function addBatches(bytes32[] calldata batches, bytes calldata ipfsData) external override onlyBatcher {
        for (uint256 i = 0; i < batches.length; i++) {
            _addBatch(batches[i], ipfsData);
        }
    }

    /// @inheritdoc IGIVBacksRelayer
    function executeBatch(uint256 _nonce, address[] calldata recipients, uint256[] calldata amounts)
        external
        override
    {
        bytes32 h = _hashBatch(_nonce, recipients, amounts);

        require(pendingBatches[h], 'GIVBacksRelayer::executeBatch: NOT_PENDING');

        pendingBatches[h] = false;
        IDistro(tokenDistroContract).sendGIVbacks(recipients, amounts);

        emit Executed(msg.sender, h);
    }

    ///
    /// VIEW FUNCTIONS:
    ///

    /// @inheritdoc IGIVBacksRelayer
    function hashBatch(uint256 _nonce, address[] calldata recipients, uint256[] calldata amounts)
        external
        pure
        override
        returns (bytes32)
    {
        return _hashBatch(_nonce, recipients, amounts);
    }

    /// @inheritdoc IGIVBacksRelayer
    function isPending(bytes32 batch) external view override returns (bool) {
        return pendingBatches[batch];
    }

    ///
    /// INTERNAL FUNCTIONS:
    ///

    function _addBatch(bytes32 batch, bytes calldata ipfsData) internal {
        pendingBatches[batch] = true;

        emit AddedBatch(msg.sender, nonce++, batch, ipfsData);
    }

    function _hashBatch(uint256 _nonce, address[] calldata recipients, uint256[] calldata amounts)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, recipients, amounts));
    }
}
