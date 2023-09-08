// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract FakeDSCV1 {
    function mint(address, uint256) external pure returns (bool) {
        return false;
    }
}
