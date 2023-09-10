// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.m.sol";

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";

contract DSCEngineHandler is Test {
    DSCEngine private immutable i_dscEngine;
    DecentralizedStablecoin private immutable i_dsc;
    address wethAddress;
    address wbtcAddress;

    int96 private constant MAX_COLLATERAL_AMOUNT = type(int96).max;
    address[] private s_collateralDepositedUsers;
    address[] private s_dscMintedUsers;

    constructor(address _dscEngineAddress, address _dscAddress) {
        i_dscEngine = DSCEngine(_dscEngineAddress);
        i_dsc = DecentralizedStablecoin(_dscAddress);

        address[] memory tokensArray = i_dscEngine.getCollateralTokens();

        wethAddress = tokensArray[0];
        wbtcAddress = tokensArray[1];
    }

    function depositCollateral(uint256 _tokenSeed, int256 _amountSeed) public {
        int256 collateralAmount = bound(_amountSeed, 0, MAX_COLLATERAL_AMOUNT);

        if (collateralAmount == 0) return;

        address collateralToken = _getValidCollateralToken(_tokenSeed);

        vm.startPrank(msg.sender);
        ERC20Mock(collateralToken).mint(msg.sender, uint256(collateralAmount));
        ERC20Mock(collateralToken).approve(address(i_dscEngine), uint256(collateralAmount));
        i_dscEngine.depositCollateral(collateralToken, uint256(collateralAmount));
        vm.stopPrank();

        bool alreadyDeposited = false;

        for (uint256 i = 0; i < s_collateralDepositedUsers.length; i++) {
            if (msg.sender == s_collateralDepositedUsers[i]) {
                alreadyDeposited = true;
                return;
            }
        }

        if (!alreadyDeposited) {
            s_collateralDepositedUsers.push(msg.sender);
        }
    }

    function mintDSC(uint256 _amountDSCSeed, uint256 _minterCountSeed) public {
        if (s_collateralDepositedUsers.length <= 0) return;

        address validMinter = s_collateralDepositedUsers[_minterCountSeed % s_collateralDepositedUsers.length];

        // Another Substitute could be `Estimated validMinter's Health Factor`.
        // If Estimated Health factor comes broken then we can't mint dsc.
        (uint256 totalDSCMintedAmount, uint256 totalDepositedCollateralInUsd) =
            i_dscEngine.getAccountInformation(validMinter);
        uint256 maxDSCMintAmount = (totalDepositedCollateralInUsd / 2) - totalDSCMintedAmount;

        if (maxDSCMintAmount <= 0) return;

        uint256 dscAmountToMint = bound(_amountDSCSeed, 0, maxDSCMintAmount);

        if (dscAmountToMint <= 0) return;

        vm.startPrank(validMinter);
        i_dscEngine.mintDSC(dscAmountToMint);
        vm.stopPrank();

        bool alreadyMinted = false;

        for (uint256 i = 0; i < s_dscMintedUsers.length; i++) {
            if (msg.sender == s_dscMintedUsers[i]) {
                alreadyMinted = true;
                return;
            }
        }

        if (!alreadyMinted) {
            s_dscMintedUsers.push(msg.sender);
        }
    }

    function redeemCollateral(uint256 _tokenSeed, int256 _amountSeed, uint256 _redeemerCountSeed) public {
        if (s_collateralDepositedUsers.length <= 0) return;

        address validRedeemer = s_collateralDepositedUsers[_redeemerCountSeed % s_collateralDepositedUsers.length];

        address collateralToken = _getValidCollateralToken(_tokenSeed);

        uint256 maxRedeemAmount = i_dscEngine.getDepositedCollateralBalance(validRedeemer, collateralToken);

        int256 redeemAmount = bound(_amountSeed, 0, int256(maxRedeemAmount));

        if (redeemAmount == 0) return;

        int256 estimatedRemainingCollateralAmount = int256(maxRedeemAmount) - redeemAmount;

        if (estimatedRemainingCollateralAmount == 0) return;

        uint256 estimatedRemainingCollateralAmountInUsd =
            i_dscEngine.getUsdValue(uint256(estimatedRemainingCollateralAmount), collateralToken);
        uint256 totalMintedDSC = i_dscEngine.getMintedDSC(validRedeemer);

        uint256 estimatedHealthFactor =
            i_dscEngine.calculateHealthFactor(totalMintedDSC, estimatedRemainingCollateralAmountInUsd);

        if (estimatedHealthFactor < i_dscEngine.getMinimumHealthFactor()) return;

        vm.startPrank(validRedeemer);
        i_dscEngine.redeemCollateral(collateralToken, uint256(redeemAmount));
        vm.stopPrank();
    }

    function burnDSC(uint256 _dscToBurnAmountSeed, uint256 _burnerSeed) public {
        if (s_dscMintedUsers.length <= 0) return;

        address validBurner = s_dscMintedUsers[_burnerSeed % s_dscMintedUsers.length];

        uint256 totalDSCMintedAmount = i_dscEngine.getMintedDSC(validBurner);

        uint256 dscAmountToBurn = bound(_dscToBurnAmountSeed, 0, totalDSCMintedAmount);

        if (dscAmountToBurn <= 0) return;

        vm.startPrank(validBurner);
        i_dsc.approve(address(i_dscEngine), dscAmountToBurn);
        i_dscEngine.burnDSC(dscAmountToBurn);
        vm.stopPrank();
    }

    function liquidate(uint256 _accountToLiquidateSeed, uint256 _collateralTokenSeed, uint256 _debtAmountToCoverSeed)
        public
    {
        if (s_dscMintedUsers.length <= 0) return;

        address validUnderCollateralizedUser = s_dscMintedUsers[_accountToLiquidateSeed % s_dscMintedUsers.length];

        if (validUnderCollateralizedUser == msg.sender) return;

        address collateralToken = _getValidCollateralToken(_collateralTokenSeed);
        uint256 maxDebtAmount = i_dscEngine.getMintedDSC(validUnderCollateralizedUser);

        uint256 debtAmountToCover = bound(_debtAmountToCoverSeed, 0, maxDebtAmount);

        if (debtAmountToCover <= 0) return;

        uint256 currentHealthFactor = i_dscEngine.getHealthFactor(validUnderCollateralizedUser);

        if (currentHealthFactor >= i_dscEngine.getMinimumHealthFactor()) return;

        vm.startPrank(msg.sender);
        i_dsc.approve(address(i_dscEngine), debtAmountToCover);
        i_dscEngine.liquidate(validUnderCollateralizedUser, collateralToken, debtAmountToCover);
        vm.stopPrank();
    }

    function depositCollateralAndMintDSC(
        uint256 _collateralTokenSeed,
        int256 _collateralAmountSeed,
        uint256 _dscAmountSeed
    ) public {
        int256 collateralAmount = bound(_collateralAmountSeed, 0, MAX_COLLATERAL_AMOUNT);

        if (collateralAmount == 0) return;

        address collateralToken = _getValidCollateralToken(_collateralTokenSeed);

        (uint256 totalDSCMintedAmount, uint256 totalDepositedCollateralInUsd) =
            i_dscEngine.getAccountInformation(msg.sender);

        uint256 collateralAmountInUsd = i_dscEngine.getUsdValue(uint256(collateralAmount), collateralToken);
        uint256 validDSCMintingAmount =
            ((collateralAmountInUsd + totalDepositedCollateralInUsd) / 2) - totalDSCMintedAmount;

        uint256 dscAmountToMint = bound(_dscAmountSeed, 0, validDSCMintingAmount);

        if (dscAmountToMint <= 0) return;

        vm.startPrank(msg.sender);
        ERC20Mock(collateralToken).mint(msg.sender, uint256(collateralAmount));
        ERC20Mock(collateralToken).approve(address(i_dscEngine), uint256(collateralAmount));
        i_dscEngine.depositCollateralAndMintDSC(collateralToken, uint256(collateralAmount), dscAmountToMint);
        vm.stopPrank();

        bool alreadyDeposited = false;
        bool alreadyMinted = false;

        for (uint256 i = 0; i < s_collateralDepositedUsers.length; i++) {
            if (msg.sender == s_collateralDepositedUsers[i]) {
                alreadyDeposited = true;
                return;
            }
        }

        for (uint256 i = 0; i < s_dscMintedUsers.length; i++) {
            if (msg.sender == s_dscMintedUsers[i]) {
                alreadyMinted = true;
                return;
            }
        }

        if (!alreadyDeposited) {
            s_collateralDepositedUsers.push(msg.sender);
        }

        if (!alreadyMinted) {
            s_dscMintedUsers.push(msg.sender);
        }
    }

    function redeemCollateralForDSC(
        uint256 _collateralTokenSeed,
        uint256 _amountToRedeemSeed,
        uint256 _amountToBurnSeed
    ) public {
        address collateralToken = _getValidCollateralToken(_collateralTokenSeed);

        uint256 depositedCollateralAmount = i_dscEngine.getDepositedCollateralBalance(msg.sender, collateralToken);

        uint256 maxCollateralRedeem = bound(_amountToRedeemSeed, 0, depositedCollateralAmount);

        if (maxCollateralRedeem <= 0) return;

        uint256 mintedDSC = i_dscEngine.getMintedDSC(msg.sender);

        uint256 amountToBurn = bound(_amountToBurnSeed, 0, mintedDSC);

        if (amountToBurn <= 0) return;

        vm.startPrank(msg.sender);
        i_dsc.approve(address(i_dscEngine), amountToBurn);
        i_dscEngine.redeemCollateralForDSC(collateralToken, maxCollateralRedeem, amountToBurn);
        vm.stopPrank();
    }

    function _getValidCollateralToken(uint256 _tokenSeed) private view returns (address) {
        if ((_tokenSeed % 2) == 0) {
            return wethAddress;
        } else {
            return wbtcAddress;
        }
    }
}
