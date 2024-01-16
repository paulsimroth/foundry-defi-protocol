// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

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
contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
