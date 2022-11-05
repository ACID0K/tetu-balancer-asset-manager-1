// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./openzeppelin/SafeERC20.sol";
import "./openzeppelin/Math.sol";
import "./third_party/balancer/IBVault.sol";
import "./interfaces/ISmartVault.sol";
import "./interfaces/IGauge.sol";
import "./AssetManagerBase.sol";
import "hardhat/console.sol";

/// @title TetuVaultAssetManager
/// @dev TetuVaultAssetManager can invest funds to the TETU vault.
/// Rewards will be claimed and distributed by governance

contract TetuVaultAssetManager is AssetManagerBase {
  using SafeERC20 for IERC20;

  // ***************************************************
  //                VARIABLES
  // ***************************************************

  address public immutable tetuVault;

  // ***************************************************
  //                  EVENTS
  // ***************************************************

  event Invested(uint256 amount);
  event Devested(uint256 amount);

  // ***************************************************
  //                CONSTRUCTOR
  // ***************************************************

  constructor(
    IBVault balancerVault_,
    address tetuVault_,
    address underlying_
  ) AssetManagerBase(balancerVault_, IERC20(underlying_)) {
    require(tetuVault_ != address(0), "zero tetu vault");
    tetuVault = tetuVault_;
    IERC20(underlying_).safeIncreaseAllowance(tetuVault_, type(uint256).max);
  }

  // ***************************************************
  //                VIEWS
  // ***************************************************

  /**
   * @dev Checks balance of managed assets
   */
  function _getAUM() internal view override returns (uint256) {
    return ISmartVault(tetuVault).underlyingBalanceInVault();
  }

  // ***************************************************
  //                MAIN LOGIC
  // ***************************************************

  /**
   * @dev Deposits capital into Tetu Vault
   * @param amount - the amount of tokens being deposited
   * @return the amount deposited
   */
  function _invest(uint256 amount) internal override returns (uint256) {
    uint256 balance = underlying.balanceOf(address(this));
    if (amount < balance) {
      balance = amount;
    }
    uint256 sharesBefore = IERC20(tetuVault).balanceOf(address(this));

    // invest to Tetu Vault
    ISmartVault(tetuVault).depositAndInvest(balance);
    uint256 sharesAfter = IERC20(tetuVault).balanceOf(address(this));

    require(sharesAfter > sharesBefore, "AM should receive shares after the deposit");
    emit Invested(balance);
    return balance;
  }

  /**
   * @dev Withdraws capital out of Tetu Vault
   * @param amountUnderlying - the amount to withdraw
   * @return the number of tokens to return to the balancerVault
   */
  function _divest(uint256 amountUnderlying) internal override returns (uint256) {
    console.log("Hello!");

    amountUnderlying = Math.min(amountUnderlying, IERC20(tetuVault).balanceOf(address(this)));
    uint256 existingBalance = underlying.balanceOf(address(this));
    if (amountUnderlying > 0) {
      ISmartVault(tetuVault).withdraw(amountUnderlying);
      uint256 newBalance = underlying.balanceOf(address(this));
      uint256 divested = newBalance - existingBalance;
      require(divested > 0, "AM should receive requested tokens after the withdraw");
      emit Devested(divested);
      return divested;
    }
    return 0;
  }

  /// @dev Rewards will be claimed by the TETU governance
  function _claim() internal override {}
}
