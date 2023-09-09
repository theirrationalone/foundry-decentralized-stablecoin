// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "./MockV3Aggregator.m.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract FakeDSCV3 is Script {
    MockV3Aggregator private immutable i_priceFeed;

    constructor(address _aggregatorPriceFeedAddress) {
        i_priceFeed = MockV3Aggregator(_aggregatorPriceFeedAddress);
    }

    function mint(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return true;
    }

    function burn(uint256) public {
        i_priceFeed.updateAnswer(0);
    }
}
