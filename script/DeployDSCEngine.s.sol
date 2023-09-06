// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSCEngine is Script {
    address[] public priceFeedAddresses;
    address[] public tokenAddresses;

    function run() external returns (DSCEngine, DecentralizedStablecoin, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 privateKey) =
            config.activeNetworkConfig();

        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        tokenAddresses = [weth, wbtc];

        vm.startBroadcast(privateKey);
        DecentralizedStablecoin dsc = new DecentralizedStablecoin();
        DSCEngine dscEngine = new DSCEngine(priceFeedAddresses, tokenAddresses, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dscEngine, dsc, config);
    }
}
