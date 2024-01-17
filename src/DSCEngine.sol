// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    ///////////////////////
    /// STATE VARIABLES ///
    ///////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    DecentralizedStableCoin private immutable i_dsc;

    ///////////////////////
    /// EVENTS ////////////
    ///////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////
    // EXTERNAL FUNCTIONS /
    ///////////////////////
    function depositCollateralAndMintDsc() external {}

    /**
     * @param tokenCollateralAddress ADrress of the token to deposit as collateral
     * @param amountCollateral Amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
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

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ///////////////////////
    /// PUBLIC FUNCTIONS //
    ///////////////////////
}
