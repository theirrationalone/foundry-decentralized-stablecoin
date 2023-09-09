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
import {FakeERC20V1} from "../mocks/FakeERC20V1.m.sol";
import {FakeERC20V2} from "../mocks/FakeERC20V2.m.sol";
import {FakeDSCV1} from "../mocks/FakeDSCV1.m.sol";
import {FakeDSCV2} from "../mocks/FakeDSCV2.m.sol";
import {FakeDSCV3} from "../mocks/FakeDSCV3.m.sol";

contract DSCEngineTest is Test {
    DSCEngine dscEngine;
    DecentralizedStablecoin dsc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address USER = makeAddr("USER");
    address LIQUIDATOR = makeAddr("LIQUIDATOR");
    uint256 private constant AMOUNT_COLLATERAL = 10 ether;
    uint256 private constant STARTING_WETH_BALANCE = 10 ether;
    uint256 private constant MAX_DSC_MINT_AMOUNT = 10000 ether;

    address[] fakePriceFeedArray;
    address[] fakeTokenArray;

    event CollateralDeposited(address indexed depositor, address indexed token, uint256 indexed amount);
    event DSCMinted(address indexed dscHolder, uint256 indexed dscAmount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );
    event DscBurned(address indexed dscBurner, address indexed dscHolder, uint256 indexed amountBurned);

    function setUp() external {
        HelperConfig config;

        DeployDSCEngine deployer = new DeployDSCEngine();
        (dscEngine, dsc, config) = deployer.run();

        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_WETH_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_WETH_BALANCE);
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
        FakeERC20V1 fakeERC20 = new FakeERC20V1();
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

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier dscMint() {
        // always attach `depositCollateral` modifier before this modifier.
        vm.startPrank(USER);
        dscEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testCalculatesCollateralAmountInUsdCorrectly() public depositCollateral {
        (, int256 latestPrice,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        uint256 extraPrecision = dscEngine.getExtraPrecision();
        uint256 precision = dscEngine.getPrecision();
        uint256 expectedCalcUsdValue = (AMOUNT_COLLATERAL * (uint256(latestPrice) * extraPrecision)) / precision;
        uint256 actualCalcUsdValue = dscEngine.getAccountCollateralData(USER);

        assertEq(actualCalcUsdValue, expectedCalcUsdValue);
    }

    function testCanMintMaxDSCWithBreakingHealthFactorSuccessfully() public depositCollateral {
        uint256 startingUserDSCBalance = dsc.balanceOf(USER);
        uint256 startingUserDSCMintedBalance = dscEngine.getMintedDSC(USER);

        vm.startPrank(USER);
        dscEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        uint256 endingUserDSCBalance = dsc.balanceOf(USER);
        uint256 endingUserDSCMintedBalance = dscEngine.getMintedDSC(USER);

        assertEq(startingUserDSCBalance, 0);
        assertEq(startingUserDSCMintedBalance, 0);
        assertEq(endingUserDSCBalance, MAX_DSC_MINT_AMOUNT);
        assertEq(endingUserDSCMintedBalance, MAX_DSC_MINT_AMOUNT);
        assertEq(startingUserDSCBalance, startingUserDSCMintedBalance);
        assertEq(endingUserDSCBalance, endingUserDSCMintedBalance);
    }

    function testShouldEmitAnEventOnSuccessfulMinting() public depositCollateral {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, false, address(dscEngine));
        emit DSCMinted(USER, MAX_DSC_MINT_AMOUNT);
        dscEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    function testShouldRecordCorrectLogsOfEventOnSuccessfulDSCMinting() public depositCollateral {
        vm.startPrank(USER);
        vm.recordLogs();
        dscEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 dscHolderProto = entries[1].topics[1];
        bytes32 dscAmountProto = entries[1].topics[2];

        address dscHolder = address(uint160(uint256(dscHolderProto)));
        uint256 dscAmount = uint256(dscAmountProto);

        assertEq(dscHolder, USER);
        assertEq(dscAmount, MAX_DSC_MINT_AMOUNT);
    }

    function testShouldRevertMintDSCIfMaxMintingLimitCrossed() public depositCollateral {
        uint256 precision = dscEngine.getPrecision();
        uint256 expectedBrokenHealthFactor = (MAX_DSC_MINT_AMOUNT * precision) / (MAX_DSC_MINT_AMOUNT + 1 ether);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__HealthfactorIsBroken.selector, expectedBrokenHealthFactor)
        );
        dscEngine.mintDSC(MAX_DSC_MINT_AMOUNT + 1 ether);
        vm.stopPrank();
    }

    function testShouldRevertMintDSCOnUnsuccessfulMinting() public {
        fakePriceFeedArray = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        fakeTokenArray = [weth, wbtc];

        FakeDSCV1 fakeDSC = new FakeDSCV1();
        DSCEngine newDscEngine = new DSCEngine(fakePriceFeedArray, fakeTokenArray, address(fakeDSC));

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(newDscEngine), AMOUNT_COLLATERAL);
        newDscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        newDscEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDSCWorksProperly() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        uint256 mintedDSC = dscEngine.getMintedDSC(USER);
        uint256 depositedCollateral = dscEngine.getDepositedCollateralBalance(USER, weth);

        assertEq(mintedDSC, MAX_DSC_MINT_AMOUNT);
        assertEq(depositedCollateral, AMOUNT_COLLATERAL);
    }

    function testRedeemCollateralWorksCorrectly() public depositCollateral {
        uint256 userStartingCollateralBalance = dscEngine.getDepositedCollateralBalance(USER, weth);

        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 userEndingCollateralBalance = dscEngine.getDepositedCollateralBalance(USER, weth);

        assertEq(userStartingCollateralBalance, AMOUNT_COLLATERAL);
        assertEq(userEndingCollateralBalance, 0);
    }

    function testShouldRevertIfRedeemCollateralAmountExceedsThanCurrentBalance() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL + 1 ether);
        vm.stopPrank();
    }

    function testCannotRedeemZeroAmount() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCannotRedeemIfNotDeposited(address _user, uint256 _amount) public {
        vm.startPrank(_user);
        vm.expectRevert();
        dscEngine.redeemCollateral(weth, _amount);
        vm.stopPrank();
    }

    function testCannotRedeemUsingInvalidToken() public {
        ERC20Mock tokenDummy = new ERC20Mock("dummy_token", "dytk", address(5), 1000e8);

        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.redeemCollateral(address(tokenDummy), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCannotRedeemIfHealthFactorBreaksOnRedeeming() public depositCollateral dscMint {
        uint256 precision = dscEngine.getPrecision();
        uint256 estimatedBrokenHealthFactor = (9000e18 * precision) / MAX_DSC_MINT_AMOUNT;
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__HealthfactorIsBroken.selector, estimatedBrokenHealthFactor)
        );
        dscEngine.redeemCollateral(weth, 1 ether);
        vm.stopPrank();
    }

    function testRedeemCollateralTransferFailsOnUnsuccessfulTransfer() public {
        FakeERC20V2 fakeToken = new FakeERC20V2();

        fakeTokenArray = [address(fakeToken)];
        fakePriceFeedArray = [wethUsdPriceFeed];

        DSCEngine newDSCEngine = new DSCEngine(fakePriceFeedArray, fakeTokenArray, address(dsc));

        vm.startPrank(USER);
        newDSCEngine.depositCollateral(address(fakeToken), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        newDSCEngine.redeemCollateral(address(fakeToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testShouldEmitAnEventOnSuccessfulRedeeming() public depositCollateral {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(USER, USER, weth, AMOUNT_COLLATERAL);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRecordsEventLogsAndAreSameAsExpected() public depositCollateral {
        vm.startPrank(USER);
        vm.recordLogs();
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 redeemFromProto = entries[1].topics[1];
        bytes32 redeemToProto = entries[1].topics[2];
        bytes32 wethTokenProto = entries[1].topics[3];
        bytes memory redeemedAmountProto = entries[1].data;

        address redeemFrom = address(uint160(uint256(redeemFromProto)));
        address redeemTo = address(uint160(uint256(redeemToProto)));
        address wethToken = address(uint160(uint256(wethTokenProto)));
        uint256 redeemedAmount = uint256(bytes32(redeemedAmountProto));

        assertEq(redeemFrom, USER);
        assertEq(redeemTo, USER);
        assertEq(wethToken, weth);
        assertEq(redeemedAmount, AMOUNT_COLLATERAL);
    }

    function testBurnsDSCSuccessfully() public depositCollateral dscMint {
        uint256 userStartingDSCBalance = dsc.balanceOf(USER);
        uint256 userStartingDSCFromEngine = dscEngine.getMintedDSC(USER);

        vm.startPrank(USER);
        dsc.approve(address(dscEngine), MAX_DSC_MINT_AMOUNT);
        dscEngine.burnDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        uint256 userEndingDSCFromEngine = dscEngine.getMintedDSC(USER);
        uint256 userEndingDSCBalance = dsc.balanceOf(USER);

        assertEq(userStartingDSCBalance, userStartingDSCFromEngine);
        assertEq(userEndingDSCBalance, userEndingDSCFromEngine);
        assertEq(userStartingDSCBalance, MAX_DSC_MINT_AMOUNT);
        assertEq(userStartingDSCFromEngine, MAX_DSC_MINT_AMOUNT);
        assertEq(userEndingDSCBalance, 0);
        assertEq(userEndingDSCFromEngine, 0);
    }

    function testCannotBurnZeroDSCThereforeExecutionReverts() public depositCollateral dscMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), MAX_DSC_MINT_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.burnDSC(0);
        vm.stopPrank();
    }

    function testCannotBurnDSCMoreThanAvailableBalance() public depositCollateral dscMint {
        vm.startPrank(address(dscEngine));
        dsc.transferOwnership(USER);
        vm.stopPrank();

        vm.startPrank(USER);
        dsc.burn(4 ether);
        dsc.transferOwnership(address(dscEngine));
        dscEngine.getMintedDSC(USER);
        dsc.balanceOf(USER);
        dsc.approve(address(dscEngine), MAX_DSC_MINT_AMOUNT);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        dscEngine.burnDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    function testBurnAmountTransferFails() public {
        fakePriceFeedArray = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        fakeTokenArray = [weth, wbtc];

        FakeDSCV2 newDSC = new FakeDSCV2();

        DSCEngine newDSCEngine = new DSCEngine(fakePriceFeedArray, fakeTokenArray, address(newDSC));

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(newDSCEngine), AMOUNT_COLLATERAL);
        newDSCEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        newDSCEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        newDSCEngine.burnDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    function testShouldEmitAnEventOnSuccessfulBurn() public depositCollateral dscMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), MAX_DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dscEngine));
        emit DscBurned(USER, USER, MAX_DSC_MINT_AMOUNT);
        dscEngine.burnDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    function testRecordsCorrectEventLogsOfBurnDSC() public depositCollateral dscMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), MAX_DSC_MINT_AMOUNT);
        vm.recordLogs();
        dscEngine.burnDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 burnerProto = entries[3].topics[1];
        bytes32 burnDSCOnBehalfOfProto = entries[3].topics[2];
        bytes32 burnAmountProto = entries[3].topics[3];

        address burner = address(uint160(uint256(burnerProto)));
        address burnOnBehalfOf = address(uint160(uint256(burnDSCOnBehalfOfProto)));
        uint256 burnAmount = uint256(burnAmountProto);

        assertEq(burner, USER);
        assertEq(burnOnBehalfOf, USER);
        assertEq(burnAmount, MAX_DSC_MINT_AMOUNT);
    }

    function testRedeemCollateralForDSCTwoTxsCorrectly() public depositCollateral dscMint {
        uint256 startingDepositedCollateralAmount = dscEngine.getDepositedCollateralBalance(USER, weth);
        uint256 startingMintedDSCAmount = dscEngine.getMintedDSC(USER);

        vm.startPrank(USER);
        dsc.approve(address(dscEngine), MAX_DSC_MINT_AMOUNT);
        dscEngine.redeemCollateralForDSC(weth, AMOUNT_COLLATERAL, MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        uint256 endingDepositedCollateralAmount = dscEngine.getDepositedCollateralBalance(USER, weth);
        uint256 endingMintedDSCAmount = dscEngine.getMintedDSC(USER);
        uint256 healthFactor = dscEngine.getHealthFactor(USER);

        assertEq(startingDepositedCollateralAmount, AMOUNT_COLLATERAL);
        assertEq(startingMintedDSCAmount, MAX_DSC_MINT_AMOUNT);
        assertEq(endingDepositedCollateralAmount, 0);
        assertEq(endingMintedDSCAmount, 0);
        assertEq(healthFactor, type(uint256).max);
    }

    function testCannotLiquidateForZeroDebts() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.liquidate(USER, weth, 0);
        vm.stopPrank();
    }

    function testCannotLiquidateForInvalidWethToken() public {
        ERC20Mock invalidToken = new ERC20Mock("INVALID_TOKEN", "INVTK", address(6), 1000e8);
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__OnlyValidTokenAllowed.selector, address(invalidToken))
        );
        dscEngine.liquidate(USER, address(invalidToken), MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    function testLiquidatorCanLiquidateAnyUnderCollateralizedUser() public depositCollateral dscMint {
        ERC20Mock(weth).mint(LIQUIDATOR, 10 ether);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), 20 ether);
        dscEngine.depositCollateral(weth, 20 ether);
        dscEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(1500e8);

        uint256 userTokenAmountFromUsd = dscEngine.getTokenAmountFromUsd(weth, dscEngine.getMintedDSC(USER));

        uint256 liquidationBonus =
            (userTokenAmountFromUsd * dscEngine.getLiquidationBonus()) / dscEngine.getLiquidationPrecision();

        uint256 totalEarningOfLiquidator = userTokenAmountFromUsd + liquidationBonus;

        uint256 expectedRemainingDepositedCollateralsOfUser =
            dscEngine.getDepositedCollateralBalance(USER, weth) - totalEarningOfLiquidator;

        uint256 expectedRemainingDSCBalanceOfLiquidator = dsc.balanceOf(LIQUIDATOR) - dscEngine.getMintedDSC(USER);

        uint256 currentHealthFactorOfUser = dscEngine.getHealthFactor(USER);
        uint256 currentHealthFactorOfLiquidator = dscEngine.getHealthFactor(LIQUIDATOR);

        console.log("Before liquidation:");
        console.log("deposited collateral user:", dscEngine.getDepositedCollateralBalance(USER, weth));
        console.log("deposited collateral liquidator:", dscEngine.getDepositedCollateralBalance(LIQUIDATOR, weth));
        console.log("minted dsc user:", dscEngine.getMintedDSC(USER));
        console.log("minted dsc liquidator:", dscEngine.getMintedDSC(LIQUIDATOR));
        console.log("weth token balance user:", ERC20Mock(weth).balanceOf(USER));
        console.log("weth token balance liquidator:", ERC20Mock(weth).balanceOf(LIQUIDATOR));
        console.log("dsc balance user:", dsc.balanceOf(USER));
        console.log("dsc balance liquidator:", dsc.balanceOf(LIQUIDATOR));

        assert(currentHealthFactorOfUser < 1e18);
        assert(currentHealthFactorOfLiquidator >= 1e18);

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dscEngine), dscEngine.getMintedDSC(USER));
        dscEngine.liquidate(USER, weth, dscEngine.getMintedDSC(USER));
        vm.stopPrank();

        uint256 actualRemainingDepositedCollateralsOfUser = dscEngine.getDepositedCollateralBalance(USER, weth);
        uint256 actualRemainingDSCBalanceOfLiquidator = dsc.balanceOf(LIQUIDATOR);
        uint256 actualEarningOfLiquidator = ERC20Mock(weth).balanceOf(LIQUIDATOR);

        uint256 updatedHealthFactorOfUser = dscEngine.getHealthFactor(USER);
        uint256 updatedHealthFactorOfLiquidator = dscEngine.getHealthFactor(LIQUIDATOR);

        console.log("After liquidation:");
        console.log("deposited collateral user:", dscEngine.getDepositedCollateralBalance(USER, weth));
        console.log("deposited collateral liquidator:", dscEngine.getDepositedCollateralBalance(LIQUIDATOR, weth));
        console.log("minted dsc user:", dscEngine.getMintedDSC(USER));
        console.log("minted dsc liquidator:", dscEngine.getMintedDSC(LIQUIDATOR));
        console.log("weth token balance user:", ERC20Mock(weth).balanceOf(USER));
        console.log("weth token balance liquidator:", ERC20Mock(weth).balanceOf(LIQUIDATOR));
        console.log("dsc balance user:", dsc.balanceOf(USER));
        console.log("dsc balance liquidator:", dsc.balanceOf(LIQUIDATOR));

        assertEq(actualRemainingDepositedCollateralsOfUser, expectedRemainingDepositedCollateralsOfUser);
        assertEq(actualRemainingDSCBalanceOfLiquidator, expectedRemainingDSCBalanceOfLiquidator);
        assertEq(actualEarningOfLiquidator, totalEarningOfLiquidator);
        assert(updatedHealthFactorOfLiquidator >= 1e18);
        assert(updatedHealthFactorOfUser >= 1e18);

        // 2000 -> 1500 <- prices raised.
        // -> 10 * 1000 -> 10000 <- total collateral value in usd
        // -> (10000 * 50) / 100 -> 5000 <- 50% of available collateral therefore it's the threshold
        // 5000 / 10000 -> 5 / 10 -> 0.5 - health factor

        // 10000 / 1500 -> 100 / 15 -> 6.667 <- eth to pay.
        // (6.667 * 10) / 100 -> 0.667 -> bonus, almost $1000 earning
        // 7.3336667 -> total to redeem
    }

    function testCannotLiquidateIfHealthFactorIsOk() public depositCollateral dscMint {
        uint256 extraFeedPrecision = dscEngine.getExtraPrecision();
        uint256 precision = dscEngine.getPrecision();
        uint256 depositedCollateralAmount = dscEngine.getDepositedCollateralBalance(USER, weth);
        uint256 mintedDSCAmount = dscEngine.getMintedDSC(USER);

        (, int256 latestPrice,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        uint256 collateralUsdValue =
            ((uint256(latestPrice) * extraFeedPrecision) * depositedCollateralAmount) / precision;

        uint256 liquidationThreshold = dscEngine.getLiquidationThreshold();
        uint256 liquidationPrecision = dscEngine.getLiquidationPrecision();

        uint256 collateralAdjustedforThreshold = (collateralUsdValue * liquidationThreshold) / liquidationPrecision;

        uint256 expectedHealthFactor = (collateralAdjustedforThreshold * precision) / mintedDSCAmount;

        vm.startPrank(address(5)); // any user.
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorIsOk.selector, expectedHealthFactor));
        dscEngine.liquidate(USER, weth, mintedDSCAmount);
        vm.stopPrank();
    }

    function testLiquidatorLiquidatesUnderCollateralizedUserButNotImprovesHealth() public {
        fakePriceFeedArray = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        fakeTokenArray = [weth, wbtc];

        FakeDSCV3 fakeDSC = new FakeDSCV3(wethUsdPriceFeed);

        DSCEngine fakeDSCEngine = new DSCEngine(fakePriceFeedArray, fakeTokenArray, address(fakeDSC));

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(fakeDSCEngine), AMOUNT_COLLATERAL);
        fakeDSCEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        fakeDSCEngine.mintDSC(MAX_DSC_MINT_AMOUNT);
        vm.stopPrank();

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(1500e8);

        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__HealthfactorNoImproved.selector);
        fakeDSCEngine.liquidate(USER, weth, 100 ether); // we want to some remaining dsc amount to not touch dsc == 0 condition.
        vm.stopPrank();
    }
}
