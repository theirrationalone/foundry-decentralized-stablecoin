// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";

contract DeployDSCEngineTest is Test {
    DeployDSCEngine deployer;

    function setUp() public {
        deployer = new DeployDSCEngine();
    }

    function testDeployDSCEngineScriptWorksCorrectly() public {
        (DSCEngine dscEngine, DecentralizedStablecoin dsc, HelperConfig config) = deployer.run();

        assertEq(address(deployer), address(DeployDSCEngine(address(deployer))));
        assertEq(address(dscEngine), dsc.owner());
        assertEq(address(config), address(HelperConfig(address(config))));
    }
}
