// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Ics23Proof, L1Header, OpL2StateProof} from "./ProofVerifier.sol";

interface LightClient {
    /**
     * addOpConsensusState adds an appHash to internal store and
     * returns the fraud proof end time, and a bool flag indicating if
     * the fraud proof window has passed according to the block's time stamp.
     */
    function addOpConsensusState(
        L1Header calldata l1header,
        OpL2StateProof calldata proof,
        uint256 height,
        uint256 appHash
    ) external returns (uint256 endTime, bool ended);

    /**
     *
     */
    function getFraudProofEndtime(uint256 height) external returns (uint256 endTime);

    /**
     * verifyMembership checks if the current state
     * can be used to perform the membership test and if so, it uses
     * the verifier to perform membership check.
     */
    function verifyMembership(Ics23Proof calldata proof, bytes memory key, bytes memory expectedValue) external;

    /**
     *
     */
    function verifyNonMembership(Ics23Proof calldata proof, bytes memory key) external;

    /**
     *
     */
    function getState(uint256 height) external view returns (uint256 appHash, uint256 fraudProofEndTime, bool ended);
}
