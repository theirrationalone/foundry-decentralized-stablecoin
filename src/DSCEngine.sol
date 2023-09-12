// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {OracleLib} from "./Libraries/OracleLib.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__PriceFeedAddressesAndTokenAddressesListMustBeSameLength();
    error DSCEngine__OnlyValidTokenAllowed(address token);
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthfactorIsBroken(uint256 healthFactor);
    error DSCEngine__HealthFactorIsOk(uint256 healthFactor);
    error DSCEngine__HealthfactorNoImproved();

    using OracleLib for AggregatorV3Interface;

    DecentralizedStablecoin private immutable i_dsc;
    mapping(address tokenAddress => address priceFeedAddress) private s_priceFeeds;
    address[] private s_collateralTokens;
    mapping(address user => mapping(address token => uint256 collateral)) private s_collateralDeposited;
    mapping(address user => uint256 dsc) private s_dscMinted;

    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant EXTRA_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;

    event CollateralDeposited(address indexed depositor, address indexed token, uint256 indexed amount);
    event DSCMinted(address indexed dscHolder, uint256 indexed dscAmount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );
    event DscBurned(address indexed dscBurner, address indexed dscHolder, uint256 indexed amountBurned);

    modifier validToken(address _collateralToken) {
        if (s_priceFeeds[_collateralToken] == address(0)) {
            revert DSCEngine__OnlyValidTokenAllowed(_collateralToken);
        }
        _;
    }

    modifier moreThanZero(uint256 _collateralAmount) {
        if (_collateralAmount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    constructor(address[] memory _priceFeedAddresses, address[] memory _tokenAddresses, address _dscAddress) {
        if (_priceFeedAddresses.length != _tokenAddresses.length) {
            revert DSCEngine__PriceFeedAddressesAndTokenAddressesListMustBeSameLength();
        }

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
            s_collateralTokens.push(_tokenAddresses[i]);
        }

        i_dsc = DecentralizedStablecoin(_dscAddress);
    }

    function depositCollateralAndMintDSC(address _collateralToken, uint256 _collateralAmount, uint256 _dscAmount)
        external
    {
        depositCollateral(_collateralToken, _collateralAmount);
        mintDSC(_dscAmount);
    }

    function depositCollateral(address _collateralTokenAddress, uint256 _collateralAmount)
        public
        validToken(_collateralTokenAddress)
        moreThanZero(_collateralAmount)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_collateralTokenAddress] += _collateralAmount;
        bool success = IERC20(_collateralTokenAddress).transferFrom(msg.sender, address(this), _collateralAmount);

        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        emit CollateralDeposited(msg.sender, _collateralTokenAddress, _collateralAmount);
    }

    function mintDSC(uint256 _dscAmount) public moreThanZero(_dscAmount) nonReentrant {
        s_dscMinted[msg.sender] += _dscAmount;

        _revertIfHealthFactorBroken(msg.sender);

        bool success = i_dsc.mint(msg.sender, _dscAmount);

        if (!success) {
            revert DSCEngine__MintFailed();
        }

        emit DSCMinted(msg.sender, _dscAmount);
    }

    function redeemCollateral(address _collateralTokenAddress, uint256 _collateralAmount)
        external
        moreThanZero(_collateralAmount)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, _collateralTokenAddress, _collateralAmount);
        _revertIfHealthFactorBroken(msg.sender);
    }

    function burnDSC(uint256 _amountToBurn) public moreThanZero(_amountToBurn) {
        _burnDSC(msg.sender, msg.sender, _amountToBurn);
        _revertIfHealthFactorBroken(msg.sender); // This should never hit / never revert.
    }

    function redeemCollateralForDSC(address _collateralTokenAddress, uint256 _collateralAmount, uint256 _amountToBurn)
        external
        moreThanZero(_collateralAmount)
        moreThanZero(_amountToBurn) // one bug in patrick's repo
    {
        _burnDSC(msg.sender, msg.sender, _amountToBurn);
        _redeemCollateral(msg.sender, msg.sender, _collateralTokenAddress, _collateralAmount);
        _revertIfHealthFactorBroken(msg.sender);
    }

    function liquidate(address _accountToLiquidate, address _collateralTokenAddress, uint256 _debtAmountToCover)
        external
        validToken(_collateralTokenAddress) // one more bug in patrick's repo
        moreThanZero(_debtAmountToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _healthFactor(_accountToLiquidate);

        if (startingHealthFactor >= MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsOk(startingHealthFactor);
        }

        uint256 tokenAmountFromUsd = _getTokenAmountFromUsd(_collateralTokenAddress, _debtAmountToCover);

        uint256 liquidationBonus = (tokenAmountFromUsd * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalAmountToRedeem = tokenAmountFromUsd + liquidationBonus;

        _redeemCollateral(_accountToLiquidate, msg.sender, _collateralTokenAddress, totalAmountToRedeem);
        _burnDSC(msg.sender, _accountToLiquidate, _debtAmountToCover);

        uint256 endingHealthFactor = _healthFactor(_accountToLiquidate);

        console.log("ending health factor:", endingHealthFactor);

        if (endingHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthfactorNoImproved();
        }

        _revertIfHealthFactorBroken(msg.sender);
    }

    function _burnDSC(address _burner, address _onBehalfOf, uint256 _amountToBurn) private {
        s_dscMinted[_onBehalfOf] -= _amountToBurn;

        bool success = i_dsc.transferFrom(_burner, address(this), _amountToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        i_dsc.burn(_amountToBurn);
        emit DscBurned(_burner, _onBehalfOf, _amountToBurn);
    }

    function _redeemCollateral(
        address _redeemFrom,
        address _redeemTo,
        address _collateralTokenAddress,
        uint256 _amountToRedeem
    ) private {
        s_collateralDeposited[_redeemFrom][_collateralTokenAddress] -= _amountToRedeem;

        bool success = IERC20(_collateralTokenAddress).transfer(_redeemTo, _amountToRedeem);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        emit CollateralRedeemed(_redeemFrom, _redeemTo, _collateralTokenAddress, _amountToRedeem);
    }

    function _getTokenAmountFromUsd(address _collateralTokenAddress, uint256 _amountInWei)
        private
        view
        returns (uint256)
    {
        (, int256 latestPrice,,,) =
            AggregatorV3Interface(s_priceFeeds[_collateralTokenAddress]).staleCheckLatestRoundData();

        return ((_amountInWei * PRECISION) / (uint256(latestPrice) * EXTRA_PRECISION));
    }

    // one more typo in patrick's repo
    function _revertIfHealthFactorBroken(address _user) private view {
        uint256 healthFactor = _healthFactor(_user);

        if (healthFactor < MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__HealthfactorIsBroken(healthFactor);
        }
    }

    function calculateHealthFactor(uint256 _totalDSCMinted, uint256 _collateralUsdValue)
        public
        pure
        returns (uint256)
    {
        if (_totalDSCMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralValueAdjustedForThreshold =
            (_collateralUsdValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralValueAdjustedForThreshold * PRECISION) / _totalDSCMinted;
    }

    function _healthFactor(address _user) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralUsdValue) = _getAccountInformation(_user);

        return calculateHealthFactor(totalDSCMinted, collateralUsdValue);
    }

    function _getAccountInformation(address _user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralUsdValue)
    {
        totalDSCMinted = s_dscMinted[_user];
        collateralUsdValue = getAccountCollateralData(_user);
    }

    function getAccountCollateralData(address _user) public view returns (uint256) {
        uint256 totalCollateralUsdValue;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            uint256 collateralAmount = s_collateralDeposited[_user][s_collateralTokens[i]];
            totalCollateralUsdValue += getUsdValue(collateralAmount, s_collateralTokens[i]);
        }
        return totalCollateralUsdValue;
    }

    function getUsdValue(uint256 _collateralAmount, address _collateralTokenAddress) public view returns (uint256) {
        (, int256 latestPrice,,,) =
            AggregatorV3Interface(s_priceFeeds[_collateralTokenAddress]).staleCheckLatestRoundData();

        return ((uint256(latestPrice) * EXTRA_PRECISION) * _collateralAmount) / PRECISION;
    }

    function getAccountInformation(address _user) external view returns (uint256, uint256) {
        return _getAccountInformation(_user);
    }

    function getHealthFactor(address _user) external view returns (uint256) {
        return _healthFactor(_user);
    }

    function getTokenAmountFromUsd(address _collateralTokenAddress, uint256 _amountInWei)
        external
        view
        returns (uint256)
    {
        return _getTokenAmountFromUsd(_collateralTokenAddress, _amountInWei);
    }

    function getDSCAddress() public view returns (address) {
        return address(i_dsc);
    }

    function getTokenAssociatedPriceFeedAddress(address _tokenAddress) public view returns (address) {
        return s_priceFeeds[_tokenAddress];
    }

    function getCollateralTokensLength() public view returns (uint256) {
        return s_collateralTokens.length;
    }

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDepositedCollateralBalance(address _user, address _collateralTokenAddress)
        public
        view
        returns (uint256)
    {
        return s_collateralDeposited[_user][_collateralTokenAddress];
    }

    function getMintedDSC(address _user) public view returns (uint256) {
        return s_dscMinted[_user];
    }

    function getMinimumHealthFactor() public pure returns (uint256) {
        return MINIMUM_HEALTH_FACTOR;
    }

    function getPrecision() public pure returns (uint256) {
        return PRECISION;
    }

    function getExtraPrecision() public pure returns (uint256) {
        return EXTRA_PRECISION;
    }

    function getLiquidationBonus() public pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationThreshold() public pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() public pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }
}
