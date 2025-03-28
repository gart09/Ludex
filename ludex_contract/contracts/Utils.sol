// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library Utils {

    function toHash (
        string memory input
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(input));
    }

    function compare (
        string memory self,
        string memory other
    ) 
        internal
        pure
        returns (bool)
    {
        return toHash(self) == toHash(other);
    }

    function toFnv1aHash(
        bytes memory input
    )
        internal
        pure
        returns (uint32)
    {
        uint32 prime = 16777619;

        uint32 hash = 2166136261;
        for (uint256 i = 0; i < input.length; i++)
        {
            hash ^= uint32(uint8(input[i]));
            hash *= prime;
        }

        return hash;
    }
    
}