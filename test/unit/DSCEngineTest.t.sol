// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Vm} from "forge-std/Vm.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {FakeERC20} from "../mocks/FakeERC20Mock.m.sol";

contract DSCEngineTest is Test {
    DSCEngine dscEngine;
    DecentralizedStablecoin dsc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address USER = makeAddr("USER");
    uint256 private constant AMOUNT_COLLATERAL = 10 ether;
    uint256 private constant STARTING_DSC_BALANCE = 10 ether;

    address[] fakePriceFeedArray;
    address[] fakeTokenArray;

    event CollateralDeposited(address indexed depositor, address indexed token, uint256 indexed amount);

    function setUp() external {
        HelperConfig config;

        DeployDSCEngine deployer = new DeployDSCEngine();
        (dscEngine, dsc, config) = deployer.run();

        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_DSC_BALANCE);
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

    function testCalculatesCorrectHealthFactor() public {
        uint256 totalDSCMinted = 10 ether;
        uint256 collateralAmount = 20 ether;

        uint256 healthFactor = dscEngine.calculateHealthFactor(totalDSCMinted, collateralAmount);

        assertGe(healthFactor, 1e18);
    }

    function testCanDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 depositedCollaterals = dscEngine.getDepositedCollateralBalance(USER, weth);

        assertEq(depositedCollaterals, AMOUNT_COLLATERAL);
    }

    function testShouldRevertDepositOnZeroCollateralAmount() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testShouldRevertDepositOnInvalidToken() public {
        ERC20Mock dummyToken = new ERC20Mock("DUMMY_TOKEN", "DMYTK", address(6), 1e11);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__OnlyValidTokenAllowed.selector, address(dummyToken))
        );
        dscEngine.depositCollateral(address(dummyToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testShouldRevertDepositCollateralOnInvalidTransfersMock() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.mockCallRevert(
            address(dscEngine),
            abi.encodeWithSignature("depositCollateral(address,uint256)", weth, AMOUNT_COLLATERAL),
            abi.encodeWithSelector(DSCEngine.DSCEngine__TransferFailed.selector)
        );
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testShouldRevertDepositCollateralOnInvalidTransfersFake() public {
        FakeERC20 fakeERC20 = new FakeERC20();
        fakePriceFeedArray = [address(fakeERC20)];
        fakeTokenArray = [address(fakeERC20)];
        DSCEngine newDSCEngine = new DSCEngine(fakePriceFeedArray, fakeTokenArray, address(dsc));

        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        newDSCEngine.depositCollateral(address(fakeERC20), AMOUNT_COLLATERAL);
    }

    function testShouldEmitAnEventOnSuccessfulCollateralDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, true, false, address(dscEngine));
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCollateralDepositShouldEmitCorrectEventLogData() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.recordLogs();
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 depositorProto = entries[2].topics[1];
        bytes32 wethTokenProto = entries[2].topics[2];
        bytes32 collateralAmountProto = entries[2].topics[3];

        address depositor = address(uint160(uint256(depositorProto)));
        address wethToken = address(uint160(uint256(wethTokenProto)));
        uint256 collateralAmount = uint256(collateralAmountProto);

        assertEq(depositor, USER);
        assertEq(wethToken, weth);
        assertEq(collateralAmount, AMOUNT_COLLATERAL);
    }
}
