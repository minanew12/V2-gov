// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IInitiative {
    /// @notice Callback hook that is called by Governance after the initiative was successfully registered
    /// @param _atEpoch Epoch at which the initiative is registered
    function onRegisterInitiative(uint16 _atEpoch) external;

    /// @notice Callback hook that is called by Governance after the initiative was unregistered
    /// @param _atEpoch Epoch at which the initiative is unregistered
    function onUnregisterInitiative(uint16 _atEpoch) external;

    /// @notice Callback hook that is called by Governance after the LQTY allocation is updated by a user
    /// @param _currentEpoch Epoch at which the LQTY allocation is updated
    /// @param _user Address of the user that updated their LQTY allocation
    /// @param _voteLQTY Allocated voting LQTY
    /// @param _vetoLQTY Allocated vetoing LQTY
    function onAfterAllocateLQTY(uint16 _currentEpoch, address _user, uint88 _voteLQTY, uint88 _vetoLQTY) external;

    /// @notice Callback hook that is called by Governance after the claim for the last epoch was distributed
    /// to the initiative
    /// @param _claimEpoch Epoch at which the claim was distributed
    /// @param _bold Amount of BOLD that was distributed
    function onClaimForInitiative(uint16 _claimEpoch, uint256 _bold) external;
}