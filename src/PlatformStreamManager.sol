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
 * @dev Исправлено под Sablier Flow v2.0.1:
 *      - create() принимает 6 параметров (без amount)
 *      - депозит вносится отдельным вызовом deposit() после create()
 *      - restart() принимает 2 параметра (streamId + ratePerSecond)
 *      - pause() принимает 1 параметр (streamId)
 */
contract PlatformStreamManager is Ownable {
    using SafeERC20 for IERC20;

    // ============ Константы ============

    /// @notice Комиссия платформы (5% = 500 basis points)
    uint256 public constant PLATFORM_FEE_BPS = 500;
    uint256 public constant BPS_DENOMINATOR = 10000;

    // ============ Состояние ============

    /// @notice Адрес контракта Sablier Flow (ЗАМЕНИТЕ НА АКТУАЛЬНЫЙ ДЛЯ TESTNET)
    ISablierFlow public sablierFlow;

    /// @notice Адрес токена для платежей (Mock USDG в тестовой сети)
    IERC20 public paymentToken;

    /// @notice Кошелёк для сбора комиссии платформы
    address public platformFeeRecipient;

    /// @notice Маппинг: streamId => создатель (блогер)
    mapping(uint256 => address) public streamCreator;

    /// @notice Маппинг: streamId => зритель (плательщик)
    mapping(uint256 => address) public streamViewer;

    /// @notice Общая сумма собранных комиссий
    uint256 public totalFeesCollected;

    // ============ События ============

    event StreamCreated(
        uint256 indexed streamId,
        address indexed creator,
        address indexed viewer,
        uint128 depositAmount,
        uint128 ratePerSecond
    );

    event StreamPaused(uint256 indexed streamId);
    event StreamRestarted(uint256 indexed streamId, uint128 ratePerSecond);
    event StreamClosed(uint256 indexed streamId);
    event PlatformFeeCollected(uint256 amount, address recipient);

    // ============ Конструктор ============

    constructor(
        address _sablierFlow,
        address _paymentToken,
        address _platformFeeRecipient
    ) Ownable(msg.sender) {
        sablierFlow = ISablierFlow(_sablierFlow);
        paymentToken = IERC20(_paymentToken);
        platformFeeRecipient = _platformFeeRecipient;

        // Одобряем Sablier Flow тратить наши токены
        paymentToken.approve(_sablierFlow, type(uint256).max);
    }

    // ============ Функции для зрителей ============

    /**
     * @notice Создаёт новый поток для просмотра контента
     * @param creator Кошелёк блогера (получатель)
     * @param depositAmount Сумма депозита в paymentToken
     * @param ratePerSecond Скорость потока (токенов в секунду, с 18 decimals)
     * @param startPaused Начать поток на паузе (true) или сразу запустить (false)
     * @return streamId ID созданного потока
     */
    function createStream(
        address creator,
        uint128 depositAmount,
        uint128 ratePerSecond,
        bool startPaused
    ) external returns (uint256 streamId) {
        require(creator != address(0), "Invalid creator");
        require(depositAmount > 0, "Deposit must be > 0");
        require(ratePerSecond > 0, "Rate must be > 0");

        // Рассчитываем комиссию платформы
        uint256 platformFee = (depositAmount * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint128 netDeposit = depositAmount - uint128(platformFee);

        // Переводим полную сумму от зрителя на этот контракт
        paymentToken.safeTransferFrom(msg.sender, address(this), depositAmount);

        // Отправляем комиссию платформе
        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
            totalFeesCollected += platformFee;
            emit PlatformFeeCollected(platformFee, platformFeeRecipient);
        }

        // ШАГ 1: Создаём поток через Sablier Flow (6 параметров, без amount)
        streamId = sablierFlow.create({
            sender: msg.sender,
            recipient: creator,
            ratePerSecond: ud21x18(ratePerSecond),
            token: paymentToken,
            startTime: uint40(block.timestamp),
            transferable: false
        });

        // ШАГ 2: Вносим депозит в созданный поток (отдельный вызов)
        sablierFlow.deposit({
            streamId: streamId,
            amount: netDeposit,
            sender: msg.sender,
            recipient: creator
        });

        // Если нужно сразу поставить на паузу
        if (startPaused) {
            sablierFlow.pause(streamId);
        }

        // Сохраняем информацию
        streamCreator[streamId] = creator;
        streamViewer[streamId] = msg.sender;

        emit StreamCreated(streamId, creator, msg.sender, netDeposit, ratePerSecond);
    }

    /**
     * @notice Пополняет существующий поток (добавляет депозит)
     * @param streamId ID потока
     * @param amount Сумма пополнения
     */
    function topUpStream(uint256 streamId, uint128 amount) external {
        require(streamViewer[streamId] == msg.sender, "Not stream viewer");
        require(amount > 0, "Amount must be > 0");

        uint256 platformFee = (amount * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint128 netAmount = amount - uint128(platformFee);

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);

        if (platformFee > 0) {
            paymentToken.safeTransfer(platformFeeRecipient, platformFee);
            totalFeesCollected += platformFee;
            emit PlatformFeeCollected(platformFee, platformFeeRecipient);
        }

        sablierFlow.deposit({
            streamId: streamId,
            amount: netAmount,
            sender: msg.sender,
            recipient: streamCreator[streamId]
        });
    }

    /**
     * @notice Ставит поток на паузу (зритель перестаёт платить)
     * @param streamId ID потока
     */
    function pauseStream(uint256 streamId) external {
        require(streamViewer[streamId] == msg.sender, "Not stream viewer");
        sablierFlow.pause(streamId);
        emit StreamPaused(streamId);
    }

    /**
     * @notice Возобновляет поток с указанной скоростью
     * @param streamId ID потока
     * @param ratePerSecond Новая скорость потока
     */
    function restartStream(uint256 streamId, uint128 ratePerSecond) external {
        require(streamViewer[streamId] == msg.sender, "Not stream viewer");
        require(ratePerSecond > 0, "Rate must be > 0");

        sablierFlow.restart({
            streamId: streamId,
            ratePerSecond: ud21x18(ratePerSecond)
        });

        emit StreamRestarted(streamId, ratePerSecond);
    }

    // ============ Функции для блогеров ============

    /**
     * @notice Выводит накопленные средства из потока
     * @param streamId ID потока
     * @param to Адрес для вывода (обычно кошелёк блогера)
     */
    function withdrawFromStream(uint256 streamId, address to) external {
        require(streamCreator[streamId] == msg.sender, "Not stream creator");
        require(to != address(0), "Invalid recipient");

        // Рассчитываем минимальную комиссию протокола (если требуется)
        uint256 fee = sablierFlow.calculateMinFeeWei(streamId);

        // Выводим максимально возможную сумму
        sablierFlow.withdrawMax{ value: fee }(streamId, to);
    }

    // ============ Административные функции ============

    /// @notice Обновляет адрес Sablier Flow (на случай обновления протокола)
    function setSablierFlow(address _newSablierFlow) external onlyOwner {
        sablierFlow = ISablierFlow(_newSablierFlow);
        paymentToken.approve(_newSablierFlow, type(uint256).max);
    }

    /// @notice Обновляет получателя комиссии
    function setPlatformFeeRecipient(address _newRecipient) external onlyOwner {
        platformFeeRecipient = _newRecipient;
    }

    /// @notice Обновляет токен платежа
    function setPaymentToken(address _newToken) external onlyOwner {
        paymentToken = IERC20(_newToken);
        paymentToken.approve(address(sablierFlow), type(uint256).max);
    }

    /// @notice Экстренный вывод любых ERC-20 токенов (только owner)
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
