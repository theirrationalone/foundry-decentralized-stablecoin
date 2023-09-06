// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.m.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 privateKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 private constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_INITIAL_ANSWER = 2000e8;
    int256 private constant BTC_INITIAL_ANSWER = 1000e8;
    uint256 private constant INITIAL_BALANCE = 1000e8;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            privateKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0) && activeNetworkConfig.wbtcUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast(ANVIL_DEFAULT_KEY);
        ERC20Mock wethToken = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_BALANCE);
        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(DECIMALS, ETH_INITIAL_ANSWER);

        ERC20Mock wbtcToken = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_BALANCE);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(DECIMALS, BTC_INITIAL_ANSWER);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethPriceFeed),
            wbtcUsdPriceFeed: address(btcPriceFeed),
            weth: address(wethToken),
            wbtc: address(wbtcToken),
            privateKey: ANVIL_DEFAULT_KEY
        });
    }
}
