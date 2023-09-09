// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";

contract DSCEngineHandler is Test {
    DSCEngine private immutable i_dscEngine;
    DecentralizedStablecoin private immutable i_dsc;
    address wethAddress;
    address wbtcAddress;

    constructor(address _dscEngineAddress, address _dscAddress) {
        i_dscEngine = DSCEngine(_dscEngineAddress);
        i_dsc = DecentralizedStablecoin(_dscAddress);

        address[] memory tokensArray = i_dscEngine.getCollateralTokens();

        wethAddress = tokensArray[0];
        wbtcAddress = tokensArray[1];
    }
}
