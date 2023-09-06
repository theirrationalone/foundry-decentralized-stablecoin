// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCEngineTest is Test {
    DSCEngine dscEngine;
    DecentralizedStablecoin dsc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address USER = makeAddr("USER");

    function setUp() external {
        HelperConfig config;

        DeployDSCEngine deployer = new DeployDSCEngine();
        (dscEngine, dsc, config) = deployer.run();

        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        vm.deal(USER, 10 ether);
    }

    function testDSCAddressIsCorrect() public {
        address dscAddress = dscEngine.getDSCAddress();
        assertEq(dscAddress, address(dsc));
    }

    function testCollateralTokensLengthIsCorrect() public {
        assertEq(dscEngine.getCollateralTokensLength(), 2);
    }

    function testCollateralTokensListItemsAreCorrect() public {
        address[] memory tokensArray = dscEngine.getCollateralTokens();
        assertEq(tokensArray[0], weth);
        assertEq(tokensArray[1], wbtc);
    }

    function testMinimumHealthFactorIsCorrect() public {
        uint256 expectedMinHealthFactor = 1e18;
        uint256 actualMinHealthFactor = dscEngine.getMinimumHealthFactor();
        assertEq(actualMinHealthFactor, expectedMinHealthFactor);
    }

    function testPrecisionIsCorrect() public {
        uint256 expectedPrecision = 1e18;
        uint256 actualPrecision = dscEngine.getPrecision();
        assertEq(actualPrecision, expectedPrecision);
    }

    function testExtraPrecisionIsCorrect() public {
        uint256 expectedExtraPrecision = 1e10;
        uint256 actualExtraPrecision = dscEngine.getExtraPrecision();
        assertEq(actualExtraPrecision, expectedExtraPrecision);
    }

    function testLiquidationBonusPercentageUnitIsCorrect() public {
        uint256 expectedLiquidationBonusPercentage = 10;
        uint256 actualLiquidationBonusPercentage = dscEngine.getLiquidationBonus();
        assertEq(actualLiquidationBonusPercentage, expectedLiquidationBonusPercentage);
    }

    function testLiquidationThresholdIsCorrect() public {
        uint256 expectedLiquidationThreshold = 50;
        uint256 actualLiquidationThreshold = dscEngine.getLiquidationThreshold();
        assertEq(actualLiquidationThreshold, expectedLiquidationThreshold);
    }

    function testLiquidationPrecisionIsCorrect() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = dscEngine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }

    function testZeroDSCMintedForAllUsersInitially(address _user) public {
        uint256 expectedMintedDSC = 0;
        uint256 actualDSCMinted = dscEngine.getMintedDSC(_user);
        assertEq(actualDSCMinted, expectedMintedDSC);
    }

    function testDepositedCollateralBalanceIsZeroForAllUsersTokens(address _user) public {
        uint256 expectedDepositedCollateral = 0;
        uint256 actualDepositedCollateralWeth = dscEngine.getDepositedCollateralBalance(_user, weth);
        uint256 actualDepositedCollateralWbtc = dscEngine.getDepositedCollateralBalance(_user, wbtc);

        assertEq(actualDepositedCollateralWeth, expectedDepositedCollateral);
        assertEq(actualDepositedCollateralWbtc, expectedDepositedCollateral);
    }

    function testAllTokenAddressesHasCorrectPriceFeed() public {
        address wethPriceFeedFetched = dscEngine.getTokenAssociatedPriceFeedAddress(weth);
        address wbtcPriceFeedFetched = dscEngine.getTokenAssociatedPriceFeedAddress(wbtc);
        assertEq(wethUsdPriceFeed, wethPriceFeedFetched);
        assertEq(wbtcUsdPriceFeed, wbtcPriceFeedFetched);
    }

    function testReturnsCorrectTokenAmount() public {
        uint256 dscAmountInUsd = 10 ether;
        (, int256 latestPrice,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        uint256 extraFeedPrecision = dscEngine.getExtraPrecision();
        uint256 precision = dscEngine.getPrecision();

        uint256 expectedTokenAmount = (dscAmountInUsd * precision) / (uint256(latestPrice) * extraFeedPrecision);

        uint256 actualTokenAmount = dscEngine.getTokenAmountFromUsd(weth, dscAmountInUsd);

        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    function testGetHealthFactorShouldBeHighForAllUsersInitially(address _user) public {
        uint256 healthFactor = dscEngine.getHealthFactor(_user);
        assertEq(healthFactor, type(uint256).max);
    }

    function testReturnsAllUsersCorrectAccountInformation(address _user) public {
        uint256 expectedMintedDSC = 0;
        uint256 expectedDepositedCollateralAmountInUsd = 0;

        (uint256 actualMintedDSC, uint256 actualDepositedCollateralAmountInUsd) = dscEngine.getAccountInformation(_user);
        assertEq(actualMintedDSC, expectedMintedDSC);
        assertEq(actualDepositedCollateralAmountInUsd, expectedDepositedCollateralAmountInUsd);
    }

    function testReturnsCorrectUsdEquivalentCollateralAmountValue() public {
        uint256 collateralAmount = 1 ether;
        (, int256 latestPrice,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        uint256 extraFeedPrecision = dscEngine.getExtraPrecision();
        uint256 precision = dscEngine.getPrecision();
        uint256 expectedUsdConvertedCollateralAmount =
            ((uint256(latestPrice) * extraFeedPrecision) * collateralAmount) / precision;
        uint256 actualUsdConvertedCollateralAmount = dscEngine.getUsdValue(collateralAmount, weth);

        assertEq(actualUsdConvertedCollateralAmount, expectedUsdConvertedCollateralAmount);
    }
}
