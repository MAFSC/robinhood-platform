// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD21x18, ud21x18 } from "@prb/math/src/UD21x18.sol";

/**
 * @title IMockStreamFlow
 * @notice Interface for MockStreamFlow — mock of Sablier Flow for testing
 */
interface IMockStreamFlow {
    function create(
        address sender,
        address recipient,
        UD21x18 ratePerSecond,
        IERC20 token,
        uint40 startTime,
        bool transferable
    ) external returns (uint256 streamId);

    function deposit(uint256 streamId, uint128 amount, address sender, address recipient) external;
    function pause(uint256 streamId) external;
    function restart(uint256 streamId, UD21x18 ratePerSecond) external;
    function withdrawMax(uint256 streamId, address to) external returns (uint128 amount);
    function calculateMinFeeWei(uint256 streamId) external view returns (uint256);
    function accruedAmount(uint256 streamId) external view returns (uint128);
    function withdrawableAmount(uint256 streamId) external view returns (uint128);
    function nextStreamId() external view returns (uint256);
}
