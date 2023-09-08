// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract FakeERC20V2 {
    function transferFrom(address, address, uint256) public pure returns (bool) {
        return true;
    }

    function transfer(address, uint256) public pure returns (bool) {
        return false;
    }
}
