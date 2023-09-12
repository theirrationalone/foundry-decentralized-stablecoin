// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract FakeV2ERC20 {
    function transferFrom(address, address, uint256) public pure returns (bool) {
        return true;
    }

    function transfer(address, uint256) public pure returns (bool) {
        bool boolean = false;
        return boolean;
    }
}
