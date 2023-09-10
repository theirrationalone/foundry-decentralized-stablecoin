// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngineHandler} from "./DSCEngineHandler.t.sol";

contract DSCEngineInvariants is StdInvariant, Test {
    DSCEngine dscEngine;
    DecentralizedStablecoin dsc;
    address weth;
    address wbtc;

    function setUp() external {
        HelperConfig config;
        DeployDSCEngine deployer = new DeployDSCEngine();
        (dscEngine, dsc, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();

        DSCEngineHandler dscEngineHandler = new DSCEngineHandler(address(dscEngine), address (dsc));
        targetContract(address(dscEngineHandler));
    }

    function invariant_totalSupplyCanNeverBeGreaterThanTotalTokenAmounts() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 wethTotalBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 wbtcTotalBalance = ERC20Mock(wbtc).balanceOf(address(dscEngine));

        uint256 wethTotalBalanceInUsd = dscEngine.getUsdValue(wethTotalBalance, weth);
        uint256 wbtcTotalBalanceInUsd = dscEngine.getUsdValue(wbtcTotalBalance, wbtc);

        assert((wethTotalBalanceInUsd + wbtcTotalBalanceInUsd) >= totalSupply);
    }

    function invariant__helperGetterFunctionAlwaysPass() public {}
}
