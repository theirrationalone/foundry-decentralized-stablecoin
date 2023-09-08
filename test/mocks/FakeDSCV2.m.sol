// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract FakeDSCV2 {
    function mint(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return false;
    }
}
