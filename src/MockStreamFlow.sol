// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UD21x18, ud21x18 } from "@prb/math/src/UD21x18.sol";

/**
 * @title MockStreamFlow
 * @notice Mock of Sablier Flow — simulates create/deposit/pause/restart/withdrawMax
 * @dev Used ONLY for testing UX of the Advertising Exchange without real Sablier Flow.
 */
contract MockStreamFlow {
    using SafeERC20 for IERC20;

    struct Stream {
        address sender;         // Payer (advertiser)
        address recipient;      // Receiver (viewer)
        address token;          // Token (axUSDG)
        uint128 ratePerSecond;  // Rate in token units
        uint128 deposited;      // Total deposited
        uint128 withdrawn;      // Total withdrawn
        uint40 startTime;       // When created
        uint40 lastPauseTime;   // When paused (0 = active)
        bool isPaused;
        bool isVoided;
    }

    uint256 public nextStreamId = 1;
    mapping(uint256 => Stream) public streams;
    mapping(uint256 => uint128) public streamAccrued;

    event CreateFlow(uint256 indexed streamId, address indexed sender, address indexed recipient, uint128 ratePerSecond, address token, uint40 startTime);
    event DepositFlow(uint256 indexed streamId, address indexed sender, address indexed recipient, uint128 amount);
    event PauseFlow(uint256 indexed streamId);
    event RestartFlow(uint256 indexed streamId, uint128 ratePerSecond);
    event WithdrawFromFlow(uint256 indexed streamId, address indexed recipient, uint128 amount);

    function create(
        address sender,
        address recipient,
        UD21x18 ratePerSecond,
        IERC20 token,
        uint40 startTime,
        bool /* transferable */
    ) external returns (uint256 streamId) {
        require(sender != address(0), "Mock: sender zero");
        require(recipient != address(0), "Mock: recipient zero");
        require(address(token) != address(0), "Mock: token zero");

        uint128 rate = uint128(UD21x18.unwrap(ratePerSecond));
        require(rate > 0, "Mock: rate zero");

        streamId = nextStreamId++;

        streams[streamId] = Stream({
            sender: sender,
            recipient: recipient,
            token: address(token),
            ratePerSecond: rate,
            deposited: 0,
            withdrawn: 0,
            startTime: startTime,
            lastPauseTime: 0,
            isPaused: false,
            isVoided: false
        });

        emit CreateFlow(streamId, sender, recipient, rate, address(token), startTime);
    }

    function deposit(uint256 streamId, uint128 amount, address sender, address /* recipient */) external {
        Stream storage s = streams[streamId];
        require(s.sender != address(0), "Mock: stream not found");
        require(!s.isVoided, "Mock: stream voided");
        require(amount > 0, "Mock: amount zero");

        _updateAccrued(streamId);
        IERC20(s.token).safeTransferFrom(sender, address(this), amount);
        s.deposited += amount;

        emit DepositFlow(streamId, sender, s.recipient, amount);
    }

    function pause(uint256 streamId) external {
        Stream storage s = streams[streamId];
        require(s.sender != address(0), "Mock: stream not found");
        require(!s.isPaused, "Mock: already paused");

        _updateAccrued(streamId);
        s.isPaused = true;
        s.lastPauseTime = uint40(block.timestamp);

        emit PauseFlow(streamId);
    }

    function restart(uint256 streamId, UD21x18 ratePerSecond) external {
        Stream storage s = streams[streamId];
        require(s.sender != address(0), "Mock: stream not found");
        require(s.isPaused, "Mock: not paused");

        uint128 rate = uint128(UD21x18.unwrap(ratePerSecond));
        require(rate > 0, "Mock: rate zero");

        s.isPaused = false;
        s.ratePerSecond = rate;
        s.lastPauseTime = 0;

        emit RestartFlow(streamId, rate);
    }

    function withdrawMax(uint256 streamId, address to) external returns (uint128 amount) {
        Stream storage s = streams[streamId];
        require(s.recipient != address(0), "Mock: stream not found");
        require(to != address(0), "Mock: to zero");

        _updateAccrued(streamId);

        uint128 available = s.deposited - s.withdrawn;
        require(available > 0, "Mock: nothing to withdraw");

        s.withdrawn += available;
        IERC20(s.token).safeTransfer(to, available);

        emit WithdrawFromFlow(streamId, to, available);
        return available;
    }

    function calculateMinFeeWei(uint256 /* streamId */) external pure returns (uint256) {
        return 0;
    }

    function accruedAmount(uint256 streamId) external view returns (uint128) {
        Stream storage s = streams[streamId];
        if (s.recipient == address(0)) return 0;
        uint128 pending = _pendingAccrual(streamId);
        return streamAccrued[streamId] + pending;
    }

    function withdrawableAmount(uint256 streamId) external view returns (uint128) {
        Stream storage s = streams[streamId];
        if (s.recipient == address(0)) return 0;

        uint128 pending = _pendingAccrual(streamId);
        uint128 totalAccrued = streamAccrued[streamId] + pending;
        uint128 depositedLeft = s.deposited - s.withdrawn;
        return totalAccrued < depositedLeft ? totalAccrued : depositedLeft;
    }

    function _updateAccrued(uint256 streamId) internal {
        uint128 pending = _pendingAccrual(streamId);
        if (pending > 0) {
            streamAccrued[streamId] += pending;
        }
    }

    function _pendingAccrual(uint256 streamId) internal view returns (uint128) {
        Stream storage s = streams[streamId];

        if (s.isPaused) {
            if (s.lastPauseTime > s.startTime) {
                uint256 pausedElapsed = s.lastPauseTime - s.startTime;
                return uint128(pausedElapsed * s.ratePerSecond);
            }
            return 0;
        }

        uint256 activeElapsed = block.timestamp - s.startTime;
        uint128 accrued = uint128(activeElapsed * s.ratePerSecond);
        uint128 depositedLeft = s.deposited - s.withdrawn;
        return accrued < depositedLeft ? accrued : depositedLeft;
    }
}
