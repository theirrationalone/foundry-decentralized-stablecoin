// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

contract FakeDSCV2 is Script {
    function mint(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        bool boolean = false;
        return boolean;
    }
}
