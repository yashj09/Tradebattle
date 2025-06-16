// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";

/// @title HookMiner - a utility for mining hook addresses
library HookMiner {
    // mask to slice out the bottom 14 bits of the address
    uint160 constant FLAG_MASK = 0x3FFF;

    // Maximum number of iterations to mine for hook address
    uint256 constant MAX_LOOP = 100_000;

    /// @dev Find a salt that produces a hook address with the desired `flags`
    function find(address deployer, uint160 flags, bytes memory creationCode, bytes memory constructorArgs)
        internal
        view
        returns (address)
    {
        address hookAddress;
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);

        for (uint256 salt = 0; salt < MAX_LOOP; salt++) {
            hookAddress = _computeAddress(deployer, salt, bytecode);
            if (uint160(hookAddress) & FLAG_MASK == flags && hookAddress.code.length == 0) {
                return hookAddress;
            }
        }
        revert("HookMiner: could not find salt");
    }

    function _computeAddress(address deployer, uint256 salt, bytes memory bytecode) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }
}
