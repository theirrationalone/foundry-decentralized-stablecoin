// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {FakeDSCV3} from "../mocks/FakeDSCV3.m.sol";

contract FakeDSCV3Test is Test {
    FakeDSCV3 fakeDscV3;
    address priceFeedAddress;

    function setUp() external {
        HelperConfig config = new HelperConfig();
        (priceFeedAddress,,,,) = config.activeNetworkConfig();

        fakeDscV3 = new FakeDSCV3(priceFeedAddress);
    }

    function testFakeDSCV3MintFunctionIsWorkingAsExpected() public {
        bool successMint = fakeDscV3.mint(address(1), 1);
        assertEq(successMint, true);
    }

    function testFakeDSCV3transferFromFunctionIsWorkingAsExpected() public {
        bool successTransferFrom = fakeDscV3.transferFrom(address(1), address(2), 1);
        assertEq(successTransferFrom, true);
    }

    function testFakeDSCV3BurnFunctionIsWorkingAsExpected() public {
        (, int256 startingEthPrice,,,) = MockV3Aggregator(priceFeedAddress).latestRoundData();
        fakeDscV3.burn(1);
        (, int256 endingEthPrice,,,) = MockV3Aggregator(priceFeedAddress).latestRoundData();

        assertEq(startingEthPrice, 2000e8);
        assertEq(endingEthPrice, 0);
        assert(startingEthPrice > endingEthPrice);
    }
}
