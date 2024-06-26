// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {L1Header, ProofVerifier, OpL2StateProof, Ics23Proof} from "../interfaces/ProofVerifier.sol";
import {LightClient} from "../interfaces/LightClient.sol";
import {L1Block} from "optimism/L2/L1Block.sol";

// OptimisticLightClient manages the appHash at different
// heights and track the fraud proof end time for them.
contract OptimisticLightClient is LightClient {
    // consensusStates maps from the height to the appHash.
    mapping(uint256 => uint256) public consensusStates;

    // fraudProofEndtime maps from the appHash to the fraud proof end time.
    mapping(uint256 => uint256) public fraudProofEndtime;
    uint256 public fraudProofWindowSeconds;
    ProofVerifier public verifier;
    L1Block public l1BlockProvider;

    error CannotUpdatePendingOptimisticConsensusState();
    error AppHashHasNotPassedFraudProofWindow();

    constructor(uint32 fraudProofWindowSeconds_, ProofVerifier verifier_, L1Block _l1BlockProvider) {
        fraudProofWindowSeconds = fraudProofWindowSeconds_;
        verifier = verifier_;
        l1BlockProvider = _l1BlockProvider;
    }

    // addOpConsensusState adds an appHash to internal store and
    // returns the fraud proof end time, and a bool flag indicating if
    // the fraud proof window has passed according to the block's
    // timestamp.
    function addOpConsensusState(
        L1Header calldata l1header,
        OpL2StateProof calldata proof,
        uint256 height,
        uint256 appHash
    ) external override returns (uint256 fraudProofEndTime, bool ended) {
        uint256 hash = consensusStates[height];
        if (hash == 0) {
            // if this is a new apphash we need to verify the provided proof. This method will revert in case
            // of invalid proof.
            verifier.verifyStateUpdate(
                l1header, proof, bytes32(appHash), l1BlockProvider.hash(), l1BlockProvider.number()
            );

            // a new appHash
            consensusStates[height] = appHash;
            uint256 endTime = block.timestamp + fraudProofWindowSeconds;
            fraudProofEndtime[appHash] = endTime;
            return (endTime, false);
        }

        if (hash == appHash) {
            uint256 endTime = fraudProofEndtime[hash];
            return (endTime, block.timestamp >= endTime);
        }

        revert CannotUpdatePendingOptimisticConsensusState();
    }

    /**
     * getState returns the appHash at the given height, and the fraud
     * proof end time.
     * 0 is returned if there isn't an appHash with the given height.
     */
    function getState(uint256 height) external view returns (uint256 appHash, uint256 fraudProofEndTime, bool ended) {
        return getInternalState(height);
    }
    /**
     * verifyMembership checks if the current trustedOptimisticConsensusState state
     * can be used to perform the membership test and if so, it uses
     * the verifier to perform membership check.
     */

    function verifyMembership(Ics23Proof calldata proof, bytes calldata key, bytes calldata expectedValue)
        external
        view
    {
        // a proof generated at height H can only be verified against state root (app hash) from block H - 1.
        // this means the relayer must have updated the contract with the app hash from the previous block and
        // that is why we use proof.height - 1 here.
        (uint256 appHash,, bool ended) = getInternalState(proof.height - 1);
        if (!ended) revert AppHashHasNotPassedFraudProofWindow();
        verifier.verifyMembership(bytes32(appHash), key, expectedValue, proof);
    }

    function verifyNonMembership(Ics23Proof calldata proof, bytes calldata key) external view {
        (uint256 appHash,, bool ended) = getInternalState(proof.height - 1);
        if (!ended) revert AppHashHasNotPassedFraudProofWindow();
        verifier.verifyNonMembership(bytes32(appHash), key, proof);
    }

    function getFraudProofEndtime(uint256 height) external view returns (uint256 fraudProofEndTime) {
        uint256 hash = consensusStates[height];
        return fraudProofEndtime[hash];
    }

    function getInternalState(uint256 height)
        public
        view
        returns (uint256 appHash, uint256 fraudProofEndTime, bool ended)
    {
        uint256 hash = consensusStates[height];
        return (hash, fraudProofEndtime[hash], hash != 0 && block.timestamp >= fraudProofEndtime[hash]);
    }
}
