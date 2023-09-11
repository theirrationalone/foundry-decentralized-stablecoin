// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";
import {DeployMockV3Aggregator} from "../../script/DeployMockV3Aggregator.s.sol";

contract DeployMockV3AggregatorTest is Test {
    DeployMockV3Aggregator deployer;

    function setUp() external {
        deployer = new DeployMockV3Aggregator();
    }

    function testMockV3AggregatorDeployScriptWorksCorrectly() public {
        MockV3Aggregator mock = deployer.run();
        address addressMock = address(MockV3Aggregator(address(mock)));

        (, int256 latestPrice,,,) = MockV3Aggregator(addressMock).latestRoundData();
        (, int256 latestPriceAnother,,,) = mock.latestRoundData();

        assertEq(address(mock), addressMock);
        assertEq(latestPrice, latestPriceAnother);
    }
}
