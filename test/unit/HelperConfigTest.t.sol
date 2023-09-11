// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";

contract HelperConfigTest is Test {
    HelperConfig config;

    function setUp() external {
        config = new HelperConfig();
    }

    function testHelperConfigSetsCorrectConfiguration() public {
        address sepoliaWethPriceFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        address sepoliaWbtcPriceFeedAddress = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        address sepoliaWethToken = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
        address sepoliaWbtcToken = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint256 myPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 anvilPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");

        HelperConfig.NetworkConfig memory sepoliaConfig = config.getSepoliaNetworkConfig();
        assertEq(sepoliaConfig.wethUsdPriceFeed, sepoliaWethPriceFeedAddress);
        assertEq(sepoliaConfig.wbtcUsdPriceFeed, sepoliaWbtcPriceFeedAddress);
        assertEq(sepoliaConfig.weth, sepoliaWethToken);
        assertEq(sepoliaConfig.wbtc, sepoliaWbtcToken);
        assertEq(sepoliaConfig.privateKey, myPrivateKey);

        HelperConfig.NetworkConfig memory anvilConfig = config.getOrCreateAnvilNetworkConfig();
        assertEq(anvilConfig.wethUsdPriceFeed, address(MockV3Aggregator(anvilConfig.wethUsdPriceFeed)));
        assertEq(anvilConfig.wbtcUsdPriceFeed, address(MockV3Aggregator(anvilConfig.wbtcUsdPriceFeed)));
        assertEq(anvilConfig.weth, address(ERC20Mock(anvilConfig.weth)));
        assertEq(anvilConfig.wbtc, address(ERC20Mock(anvilConfig.wbtc)));
        assertEq(anvilConfig.privateKey, anvilPrivateKey);

        vm.chainId(11155111);
        HelperConfig anotherConfig = new HelperConfig();
        (
            address anotherWethPriceFeedAddress,
            address anotherWbtcPriceFeedAddress,
            address anotherWeth,
            address anotherWbtc,
        ) = anotherConfig.activeNetworkConfig();

        assert(anotherWethPriceFeedAddress != anvilConfig.wethUsdPriceFeed);
        assert(anotherWbtcPriceFeedAddress != anvilConfig.wbtcUsdPriceFeed);
        assert(anotherWeth != anvilConfig.weth);
        assert(anotherWbtc != anvilConfig.wbtc);
    }
}
