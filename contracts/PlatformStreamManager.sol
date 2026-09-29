// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ud21x18 } from "@prb/math/src/UD21x18.sol";
import { ISablierFlow } from "@sablier/flow/src/interfaces/ISablierFlow.sol";

/**
 * @title PlatformStreamManager
 * @notice Обёртка над Sablier Flow для платформы монетизации блогеров
 */
contract PlatformStreamManager is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant PLATFORM_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    ISablierFlow public sablierFlow;
    IERC20 public paymentToken;
    address public platformFeeRecipient;

    mapping(uint256 => address) public streamCreator;
    mapping(uint256 => address) public streamViewer;
    uint256 public totalFeesCollected;

    event StreamCreated(uint256 indexed streamId, address indexed creator, address indexed viewer, uint128 depositAmount, uint128 ratePerSecond);
    event StreamPaused(uint256 indexed streamId);
    event StreamRestarted(uint256 indexed streamId, uint128 ratePerSecond);
    event PlatformFeeCollected(uint256 amount, address recipient);

    constructor(
        address _sablierFlow,
        address _paymentToken,
        address _platformFeeRecipient
    ) Ownable(msg.sender) {
        sablierFlow = ISablierFlow(_sablierFlow);
        paymentToken = IERC20(_paymentToken);
        platformFeeRecipient = _platformFeeRecipient;
        paymentToken.approve(_sablierFlow, type(uint256).max);
    }

    function createStream(
        address creator,
        uint128 depositAmount,
        uint128 ratePerSecond,
        bool startPaused
    ) external returns (uint256 streamId) {
        require(creator != address(0), "Invalid creator");
        require(depositAmount > 0, "Deposit must be > 0");
        require(ratePerSecond > 0, "Rate must be > 0");

        uint256 platformFee = (depositAmount * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint128 netDeposit = depositAmount - uint128(platformFee);

        paymentToken.safeTransferFrom(msg.sender, address(this), depositAmount);

        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
            totalFeesCollected += platformFee;
            emit PlatformFeeCollected(platformFee, platformFeeRecipient);
        }

        // Создаём поток через Sablier Flow
        streamId = sablierFlow.create({
            sender: msg.sender,
            recipient: creator,
            ratePerSecond: ud21x18(ratePerSecond),
            token: paymentToken,
            startTime: uint40(block.timestamp),
            isTransferable: false,
            amount: netDeposit
        });

        if (startPaused) {
            sablierFlow.pause(streamId);
        }

        streamCreator[streamId] = creator;
        streamViewer[streamId] = msg.sender;

        emit StreamCreated(streamId, creator, msg.sender, netDeposit, ratePerSecond);
    }

    function topUpStream(uint256 streamId, uint128 amount) external {
        require(streamViewer[streamId] == msg.sender, "Not stream viewer");
        require(amount > 0, "Amount must be > 0");

        uint256 platformFee = (amount * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint128 netAmount = amount - uint128(platformFee);

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);

        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
            totalFeesCollected += platformFee;
        }

        sablierFlow.deposit(streamId, netAmount, msg.sender, streamCreator[streamId]);
    }

    function pauseStream(uint256 streamId) external {
        require(streamViewer[streamId] == msg.sender, "Not stream viewer");
        sablierFlow.pause(streamId);
        emit StreamPaused(streamId);
    }

    function restartStream(uint256 streamId, uint128 ratePerSecond) external {
        require(streamViewer[streamId] == msg.sender, "Not stream viewer");
        sablierFlow.restart(streamId, ud21x18(ratePerSecond));
        emit StreamRestarted(streamId, ratePerSecond);
    }

    function withdrawFromStream(uint256 streamId, address to) external {
        require(streamCreator[streamId] == msg.sender, "Not stream creator");
        require(to != address(0), "Invalid recipient");

        uint256 fee = sablierFlow.calculateMinFeeWei(streamId);
        sablierFlow.withdrawMax{ value: fee }(streamId, to);
    }

    function setSablierFlow(address _newSablierFlow) external onlyOwner {
        sablierFlow = ISablierFlow(_newSablierFlow);
        paymentToken.approve(_newSablierFlow, type(uint256).max);
    }

    function setPlatformFeeRecipient(address _newRecipient) external onlyOwner {
        platformFeeRecipient = _newRecipient;
    }

    function setPaymentToken(address _newToken) external onlyOwner {
        paymentToken = IERC20(_newToken);
        paymentToken.approve(address(sablierFlow), type(uint256).max);
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
