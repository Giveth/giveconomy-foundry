// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

/**
 * @title IGIVBacksRelayer
 * @dev This is the interface for a GivBacks `Relayer`.
 *
 * The purpose of the relayer is to allow a `Distributor` to split a call to
 * the `sendGIVbacks` `TokenDistro` function into multiple batches. This is
 * useful as the number of GIVBacks the distirbutor can send can exceed the
 * block gas limit.
 *
 * The relayer implementation allows a `Batcher` role to upload a number of
 * batch hashes. Each batch hash is a keccak256 hash of an ordered list of
 * parameters passed to `sendGIVBacks`.
 *
 * The relayer implementation is not expected to store batch data, so relay
 * callers, should keep it available offline.
 *
 * Once the list of batches is uploaded, anyone can perform an `executeBatch`
 * call by passing a list of parameters to be passed to `sendGIVBacks`. The
 * relayer will validate the batch parameters against the hash and execute the
 * `sendGIVBacks` call.
 *
 * The contract is upgradeable using the cannonical OpenZeppelin transparent
 * proxy.
 */
interface IGIVBacksRelayer {
    /**
     * @dev Emit when a batch is added to the Relayer.
     * @param batcher - The address of the `BATCHER_ROLE` that created the batch
     * @param nonce - The nonce attached to this batch
     * @param batch - Hash of the added batch
     */
    event AddedBatch(address indexed batcher, uint256 nonce, bytes32 batch, bytes ipfsData);

    /**
     * @dev Emit when a batch is sucessfully executed.
     * @param executor - The address that called this function
     * @param batch - The batch hash
     */
    event Executed(address indexed executor, bytes32 batch);

    /**
     * @dev This function will add a batch hash to the Relayer and set it as
     * pending. Pending batches can later be executed by calling `executeBatch`.
     *
     * NOTE: This does not take into account possible collisions, a valid nonce
     * MUST be passed during batch creation.
     *
     * Emits the `AddedBatch` event.
     *
     * @param batch - A batch that can be executed
     */
    function addBatch(bytes32 batch, bytes calldata ipfsData) external;

    /**
     * @dev This function will add each batch from the list to the Relayer.
     *
     * @param batches - A list of batches that can be executed
     */
    function addBatches(bytes32[] calldata batches, bytes calldata ipfsData) external;

    /**
     * @dev This function will try and execute a batch.
     * The batch is formed from a nonce and parameters that are expected to be
     * passed to `TokenDistro.sendGIVbacks`.
     *
     * The function will revert if the batch is not pending to be executed.
     * @param _nonce - Nonce to prevent batch collisions
     * @param recipients - Parameter passed
     * @param amounts  - Parameter passed
     */
    function executeBatch(
        uint256 _nonce,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;

    /**
     * @dev This function will produce a hash of parameters for the
     * `TokenDistro.sendGIVbacks` call. The hash uniquely identifies a batch
     * that a `BATCHER_ROLE` can pass to `createBatches` to prepare for
     * execution.
     *
     * NOTE: a valid nonce must be passed to prevent batch collisions.
     *
     * @param _nonce - Nonce to prevent batch collisions
     * @param recipients - Parameter passed
     * @param amounts  - Parameter passed
     * @return The batch hash
     */
    function hashBatch(
        uint256 _nonce,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external pure returns (bytes32);

    /**
     * @dev This function will return the pending status of a batch.
     * @param batch - The hash of the batch to check
     * @return True, if the batch is pending.
     */
    function isPending(bytes32 batch) external view returns (bool);
}
