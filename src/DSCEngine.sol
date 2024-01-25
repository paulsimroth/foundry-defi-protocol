// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author paulsimroth
 *
 * This system is designed to be as minimal as possible and have the Token maintain a peg of 1 Token == 1 US$
 *
 * This stablecoin has the properties:
 * - Exogenous collateral
 * - US Dollar pegging
 * - Stabilization Algorithm
 *
 * This system should always be over collateralized. At no point should the value of all collateral <= US$ backed value of all DSC
 *
 * @notice Tis contract is the core of the DSC System. It handles all logic fo minting and redeeming DSC, aswell as depositing and drawing collateral.
 */
contract DSCEngine is ReentrancyGuard {
    ///////////////////////
    /// ERRORS ////////////
    ///////////////////////
    error DSCEngine__NeedsValueMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsGood();

    ///////////////////////
    /// STATE VARIABLES ///
    ///////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant RECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATOR_BONUS = 10; // 10% Bonus for Liquidators

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ///////////////////////
    /// EVENTS ////////////
    ///////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

    ///////////////////////
    /// MODIFIERS /////////
    ///////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsValueMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////////
    /// FUNCTIONS /////////
    ///////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustHaveSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////
    // EXTERNAL FUNCTIONS /
    ///////////////////////

    /**
     * @param tokenCollateralAddress address of token to be deposited as collateral
     * @param amountCollateral amount of collateral to deposit
     * @param amountDscToMint amount of DecentralizesStableCoin to mint
     * @notice this function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @param tokenCollateralAddress ADrress of the token to deposit as collateral
     * @param amountCollateral Amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * This function burns DSC and redeems the underlying collateral in one transaction
     * @param tokenCollateralAddress Address of Collateral to redeem
     * @param amountCollateral Amount of collateral to redeem
     * @param amountDscToBurn Amount of DSC which will be burned
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // healthFactor gets checked by redeemCollateral()
    }

    /**
     * To redeem collateral:
     * - 1: health factor must be over 1 after collateral is pulled
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param amountDscToMint The amount of DSC Token to mint
     * @notice They must have more collateral value than the minimum threshhold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_dscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        s_dscMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * If someone is near to undercollaterlization, you can liquidate them and get payed for it
     * @param collateral The erc20 token address of the collateral to liquidate
     * @param user The user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover Amount of DSC you want to burn to improve the user healthFactor
     *
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking the users funds
     * @notice This function working assumes the protocol will be about 200% overcollateralized in order for this to work.
     * @notice A known bug would be if the protocol were 100% or less collaterlazied, then we would not be able to incentivize the liquidators.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // check healtFactor of user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsGood();
        }

        // We want to burn DSC debt and take collateral
        // Example of bad healthFactor: User has 140$ in ETH and 100$ in DSC; deptToCover = 100$
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        // Give 10% Bonus to liquidator
        // Liquidation in case the protocol is insolvent
        // we sweep extra amounts into treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
    }

    function getHealthFactor() external view {}

    ///////////////////////////////////
    /// PRIVATE & INTERNAL FUNCTIONS //
    ///////////////////////////////////
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_dscMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /**
     * Returns how close to liquidation a user is.
     * If user goes below 1, they get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC Minted
        // total collateral Value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForTreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForTreshold * LIQUIDATION_PRECISION) / totalDscMinted;
    }

    // 1: Check Health Fact (enough collateral)
    // 2: Otherwise revert
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////
    /// PUBLIC & EXTERNAL VIEW FUNCTIONS ///
    ////////////////////////////////////////
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / RECISION;
    }

    function getTokenAmountFromUsd(address collateralToken, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateralToken]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // Example: ($10e18 * 1e18) / ($2000e8 * 1e10) == 0.05 ETH
        (usdAmountInWei * LIQUIDATION_PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }
}
