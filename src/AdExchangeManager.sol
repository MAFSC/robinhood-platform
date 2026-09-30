// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UD21x18, ud21x18 } from "@prb/math/src/UD21x18.sol";
import { IMockStreamFlow } from "./interfaces/IMockStreamFlow.sol";

/**
 * @title AdExchangeManager
 * @notice Advertising Exchange on Blockchain — advertisers pay viewers for watching ads
 * @dev Implements dynamic rates: first N viewers get higher rate, rest get lower rate
 * @dev Uses tier-based reward system to manage advertiser budgets efficiently
 */
contract AdExchangeManager is Ownable {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Platform fee (5% = 500 basis points)
    uint256 public constant PLATFORM_FEE_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ============ Structs ============

    /**
     * @notice Campaign created by an advertiser to reward viewers
     */
    struct Campaign {
        address advertiser;          // Advertiser who funds the campaign
        address token;               // Token for rewards (axUSDG)
        uint128 totalBudget;         // Total budget for the campaign
        uint128 spentBudget;         // Amount already spent on rewards
        uint128 tier1Rate;           // Rate for first tier (e.g., 0.01 USDG/sec)
        uint128 tier2Rate;           // Rate for second tier (e.g., 0.001 USDG/sec)
        uint32 tier1Limit;           // Number of viewers in tier 1 (e.g., 100)
        uint32 tier1Count;           // Current count of tier 1 viewers
        uint32 totalViewers;         // Total viewers who joined
        uint40 createdAt;
        uint40 expiresAt;
        bool isActive;
    }

    /**
     * @notice Individual viewer session within a campaign
     */
    struct ViewerSession {
        uint256 campaignId;
        uint256 streamId;            // Stream ID in MockStreamFlow
        address viewer;
        uint128 ratePerSecond;       // Rate assigned to this viewer
        uint40 startedAt;
        uint40 lastUpdateAt;
        uint128 earned;              // Total earned by viewer
        bool isActive;
    }

    // ============ State ============

    IMockStreamFlow public streamFlow;
    IERC20 public paymentToken;
    address public platformFeeRecipient;

    uint256 public nextCampaignId = 1;
    uint256 public nextSessionId = 1;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => ViewerSession) public sessions;
    mapping(uint256 => uint256[]) public campaignSessions;  // campaignId => sessionIds
    mapping(address => uint256[]) public viewerSessions;     // viewer => sessionIds

    uint256 public totalFeesCollected;

    // ============ Events ============

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed advertiser,
        uint128 totalBudget,
        uint128 tier1Rate,
        uint128 tier2Rate,
        uint32 tier1Limit
    );

    event ViewerJoined(
        uint256 indexed campaignId,
        uint256 indexed sessionId,
        address indexed viewer,
        uint128 ratePerSecond
    );

    event ViewerPaused(uint256 indexed sessionId, address indexed viewer);
    event ViewerResumed(uint256 indexed sessionId, address indexed viewer);
    event ViewerWithdrew(uint256 indexed sessionId, address indexed viewer, uint128 amount);
    event CampaignClosed(uint256 indexed campaignId);
    event PlatformFeeCollected(uint256 amount, address recipient);

    // ============ Constructor ============

    constructor(
        address _streamFlow,
        address _paymentToken,
        address _platformFeeRecipient
    ) Ownable(msg.sender) {
        streamFlow = IMockStreamFlow(_streamFlow);
        paymentToken = IERC20(_paymentToken);
        platformFeeRecipient = _platformFeeRecipient;
        paymentToken.approve(_streamFlow, type(uint256).max);
    }

    // ============ Campaign Management (Advertiser) ============

    /**
     * @notice Create a new advertising campaign with dynamic tier-based rates
     * @param totalBudget Total budget in paymentToken
     * @param tier1Rate Rate for first tier viewers (in token units per second)
     * @param tier2Rate Rate for second tier viewers (in token units per second)
     * @param tier1Limit Number of viewers in tier 1 (e.g., 100)
     * @param duration Campaign duration in seconds
     * @return campaignId ID of the created campaign
     */
    function createCampaign(
        uint128 totalBudget,
        uint128 tier1Rate,
        uint128 tier2Rate,
        uint32 tier1Limit,
        uint40 duration
    ) external returns (uint256 campaignId) {
        require(totalBudget > 0, "Budget must be > 0");
        require(tier1Rate > 0, "Tier1 rate must be > 0");
        require(tier2Rate > 0, "Tier2 rate must be > 0");
        require(tier1Limit > 0, "Tier1 limit must be > 0");
        require(duration > 0, "Duration must be > 0");

        // Calculate platform fee
        uint256 platformFee = (totalBudget * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint128 netBudget = totalBudget - uint128(platformFee);

        // Transfer full amount from advertiser
        paymentToken.safeTransferFrom(msg.sender, address(this), totalBudget);

        // Send platform fee
        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
            totalFeesCollected += platformFee;
            emit PlatformFeeCollected(platformFee, platformFeeRecipient);
        }

        campaignId = nextCampaignId++;

        campaigns[campaignId] = Campaign({
            advertiser: msg.sender,
            token: address(paymentToken),
            totalBudget: netBudget,
            spentBudget: 0,
            tier1Rate: tier1Rate,
            tier2Rate: tier2Rate,
            tier1Limit: tier1Limit,
            tier1Count: 0,
            totalViewers: 0,
            createdAt: uint40(block.timestamp),
            expiresAt: uint40(block.timestamp) + duration,
            isActive: true
        });

        emit CampaignCreated(campaignId, msg.sender, netBudget, tier1Rate, tier2Rate, tier1Limit);
    }

    /**
     * @notice Close a campaign and refund remaining budget to advertiser
     */
    function closeCampaign(uint256 campaignId) external {
        Campaign storage c = campaigns[campaignId];
        require(c.advertiser == msg.sender, "Not campaign owner");
        require(c.isActive, "Campaign not active");

        c.isActive = false;

        // Refund remaining budget
        uint128 remaining = c.totalBudget - c.spentBudget;
        if (remaining > 0) {
            paymentToken.safeTransfer(c.advertiser, remaining);
        }

        emit CampaignClosed(campaignId);
    }

    // ============ Viewer Actions ============

    /**
     * @notice Viewer joins a campaign and starts earning rewards
     * @param campaignId ID of the campaign to join
     * @return sessionId ID of the created session
     */
    function joinCampaign(uint256 campaignId) external returns (uint256 sessionId) {
        Campaign storage c = campaigns[campaignId];
        require(c.isActive, "Campaign not active");
        require(block.timestamp < c.expiresAt, "Campaign expired");
        require(c.spentBudget < c.totalBudget, "Campaign budget exhausted");

        // Determine rate based on tier
        uint128 rate;
        if (c.tier1Count < c.tier1Limit) {
            rate = c.tier1Rate;
            c.tier1Count++;
        } else {
            rate = c.tier2Rate;
        }

        // Create stream: sender = advertiser, recipient = viewer
        sessionId = nextSessionId++;

        uint256 streamId = streamFlow.create({
            sender: c.advertiser,       // Advertiser pays
            recipient: msg.sender,       // Viewer receives
            ratePerSecond: ud21x18(rate),
            token: paymentToken,
            startTime: uint40(block.timestamp),
            transferable: false
        });

        // Deposit a portion of budget into the stream for this viewer
        // For testing: deposit 1% of remaining budget per viewer
        uint128 depositForViewer = (c.totalBudget - c.spentBudget) / 100;
        if (depositForViewer > 0) {
            paymentToken.approve(address(streamFlow), depositForViewer);
            streamFlow.deposit(streamId, depositForViewer, address(this), msg.sender);
        }

        // Pause the stream — viewer must call resumeViewing() to start earning
        streamFlow.pause(streamId);

        sessions[sessionId] = ViewerSession({
            campaignId: campaignId,
            streamId: streamId,
            viewer: msg.sender,
            ratePerSecond: rate,
            startedAt: uint40(block.timestamp),
            lastUpdateAt: uint40(block.timestamp),
            earned: 0,
            isActive: true
        });

        campaignSessions[campaignId].push(sessionId);
        viewerSessions[msg.sender].push(sessionId);
        c.totalViewers++;

        emit ViewerJoined(campaignId, sessionId, msg.sender, rate);
    }

    /**
     * @notice Viewer starts or resumes watching — stream starts flowing
     */
    function resumeViewing(uint256 sessionId) external {
        ViewerSession storage s = sessions[sessionId];
        require(s.viewer == msg.sender, "Not session owner");
        require(s.isActive, "Session not active");

        Campaign storage c = campaigns[s.campaignId];
        require(c.isActive, "Campaign not active");

        streamFlow.restart(s.streamId, ud21x18(s.ratePerSecond));
        s.lastUpdateAt = uint40(block.timestamp);

        emit ViewerResumed(sessionId, msg.sender);
    }

    /**
     * @notice Viewer pauses watching — stream stops flowing
     */
    function pauseViewing(uint256 sessionId) external {
        ViewerSession storage s = sessions[sessionId];
        require(s.viewer == msg.sender, "Not session owner");
        require(s.isActive, "Session not active");

        streamFlow.pause(s.streamId);
        s.lastUpdateAt = uint40(block.timestamp);

        emit ViewerPaused(sessionId, msg.sender);
    }

    /**
     * @notice Viewer withdraws accumulated rewards
     */
    function withdrawRewards(uint256 sessionId) external {
        ViewerSession storage s = sessions[sessionId];
        require(s.viewer == msg.sender, "Not session owner");
        require(s.isActive, "Session not active");

        uint128 amount = streamFlow.withdrawMax(s.streamId, msg.sender);
        s.earned += amount;

        // Update campaign spent budget
        Campaign storage c = campaigns[s.campaignId];
        c.spentBudget += amount;

        emit ViewerWithdrew(sessionId, msg.sender, amount);
    }

    /**
     * @notice Check how much a viewer can withdraw right now
     */
    function getWithdrawableAmount(uint256 sessionId) external view returns (uint128) {
        ViewerSession storage s = sessions[sessionId];
        if (!s.isActive) return 0;
        return streamFlow.withdrawableAmount(s.streamId);
    }

    /**
     * @notice Get all sessions for a viewer
     */
    function getViewerSessions(address viewer) external view returns (uint256[] memory) {
        return viewerSessions[viewer];
    }

    /**
     * @notice Get all sessions for a campaign
     */
    function getCampaignSessions(uint256 campaignId) external view returns (uint256[] memory) {
        return campaignSessions[campaignId];
    }

    /**
     * @notice Get campaign details
     */
    function getCampaign(uint256 campaignId) external view returns (Campaign memory) {
        return campaigns[campaignId];
    }

    /**
     * @notice Get session details
     */
    function getSession(uint256 sessionId) external view returns (ViewerSession memory) {
        return sessions[sessionId];
    }

    // ============ Admin Functions ============

    function setStreamFlow(address _newStreamFlow) external onlyOwner {
        streamFlow = IMockStreamFlow(_newStreamFlow);
        paymentToken.approve(_newStreamFlow, type(uint256).max);
    }

    function setPlatformFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Zero address");
        platformFeeRecipient = _newRecipient;
    }

    function setPaymentToken(address _newToken) external onlyOwner {
        paymentToken = IERC20(_newToken);
        paymentToken.approve(address(streamFlow), type(uint256).max);
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
