// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.m.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMockV3Aggregator is Script {
    function run() external returns (MockV3Aggregator) {
        HelperConfig config = new HelperConfig();
        (,,,, uint256 privateKey) = config.activeNetworkConfig();

        vm.startBroadcast(privateKey);
        MockV3Aggregator priceFeed = new MockV3Aggregator(8, 2000e8);
        vm.stopBroadcast();
        return priceFeed;
    }
}
