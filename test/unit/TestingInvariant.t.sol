// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DSCEngineInvariants} from "../fuzz/DSCEngineInvariants.t.sol";
import {DSCEngineHandler} from "../fuzz/DSCEngineHandler.t.sol";

contract TestingInvariant is Test {
    DSCEngineInvariants deployer;
    DSCEngineHandler dscEngineHandler;

    function setUp() external {
        deployer = new DSCEngineInvariants();

        DeployDSCEngine deployerDSCEngine = new DeployDSCEngine();
        (DSCEngine dscEngine, DecentralizedStablecoin dsc,) = deployerDSCEngine.run();
        dscEngineHandler = new DSCEngineHandler(address(dscEngine), address (dsc));
    }

    function testInvariantsWorkingWell() public {
        deployer.setUp();
        deployer.invariant_totalSupplyCanNeverBeGreaterThanTotalTokenAmounts();
        deployer.invariant_helperGetterFunctionAlwaysPass();
    }

    function testInvariantsHandlerWorkingWell() public {
        dscEngineHandler.depositCollateral(1, 1);
        dscEngineHandler.mintDSC(1, 1);
        dscEngineHandler.redeemCollateral(1, 1, 1);
        dscEngineHandler.depositCollateralAndMintDSC(1, 1, 1);
        dscEngineHandler.redeemCollateralForDSC(1, 1, 1);
        dscEngineHandler.burnDSC(1, 1);
        dscEngineHandler.liquidate(1, 1, 1);

        dscEngineHandler.depositCollateral(0, 0);
        dscEngineHandler.mintDSC(0, 0);
        dscEngineHandler.redeemCollateral(0, 0, 0);
        dscEngineHandler.depositCollateralAndMintDSC(0, 0, 0);
        dscEngineHandler.redeemCollateralForDSC(0, 0, 0);
        dscEngineHandler.burnDSC(0, 0);
        dscEngineHandler.liquidate(0, 0, 0);

        dscEngineHandler.depositCollateral(2, 2);
        dscEngineHandler.mintDSC(2, 2);
        dscEngineHandler.redeemCollateral(2, 2, 2);
        dscEngineHandler.depositCollateralAndMintDSC(2, 2, 2);
        dscEngineHandler.redeemCollateralForDSC(2, 2, 2);
        dscEngineHandler.burnDSC(2, 2);
        dscEngineHandler.liquidate(2, 2, 2);
    }
}
