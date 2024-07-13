// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILiquidityGauge} from "./../src/interfaces/ILiquidityGauge.sol";

import {BribeInitiative} from "./BribeInitiative.sol";

contract CurveV2GaugeRewards is BribeInitiative {
    ILiquidityGauge public immutable gauge;
    uint256 public immutable duration;

    constructor(address _governance, address _bold, address _bribeToken, address _gauge, uint256 _duration)
        BribeInitiative(_governance, _bold, _bribeToken)
    {
        gauge = ILiquidityGauge(_gauge);
        duration = _duration;
    }

    function depositIntoGauge() external returns (uint256) {
        uint256 amount = governance.claimForInitiative(address(this));
        bold.approve(address(gauge), amount);
        gauge.deposit_reward_token(address(bold), amount, duration);
        return amount;
    }
}
