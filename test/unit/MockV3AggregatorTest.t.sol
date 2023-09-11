// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";
import {DeployMockV3Aggregator} from "../../script/DeployMockV3Aggregator.s.sol";

contract MockV3AggregatorTest is Test {
    MockV3Aggregator priceFeed;

    function setUp() external {
        DeployMockV3Aggregator deployer = new DeployMockV3Aggregator();
        priceFeed = deployer.run();
    }

    function testPriceConverterBehaveCorrectly() public {
        (, int256 latestPrice,,,) = priceFeed.latestRoundData();
        assertEq(latestPrice, 2000e8);

        uint8 decimals = priceFeed.decimals();
        assertEq(decimals, 8);

        priceFeed.updateAnswer(1000e8);
        assertEq(priceFeed.latestAnswer(), 1000e8);

        priceFeed.updateRoundData(2, 1500, block.timestamp, block.timestamp);
        (uint80 updatedRoundId, int256 updatedAnswer, uint256 startedAt, uint256 updatedAt, uint80 updatedAnswerInRound)
        = priceFeed.latestRoundData();
        assertEq(updatedRoundId, 2);
        assertEq(updatedAnswerInRound, 2);
        assertEq(updatedAnswer, 1500);
        assert(startedAt > 0);
        assert(updatedAt > 0);

        (uint80 roundId, int256 answer, uint256 updatedStartedAt, uint256 updatedUpdatedAt, uint80 answeredInRound) =
            priceFeed.getRoundData(updatedRoundId);
        assertEq(updatedRoundId, roundId);
        assertEq(updatedAnswerInRound, answeredInRound);
        assertEq(updatedAnswer, answer);
        assertEq(startedAt, updatedStartedAt);
        assertEq(updatedAt, updatedUpdatedAt);

        string memory description = priceFeed.description();

        assertEq(
            keccak256(abi.encodePacked("v0.6/tests/MockV3Aggregator.sol")), keccak256(abi.encodePacked(description))
        );
    }
}
