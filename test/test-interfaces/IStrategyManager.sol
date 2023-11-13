pragma solidity ^0.8.10;

interface IStrategyManager {
    event Deposit(address depositor, address token, address strategy, uint256 shares);
    event Initialized(uint8 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account, uint256 newPausedStatus);
    event PauserRegistrySet(address pauserRegistry, address newPauserRegistry);
    event ShareWithdrawalQueued(address depositor, uint96 nonce, address strategy, uint256 shares);
    event StrategyAddedToDepositWhitelist(address strategy);
    event StrategyRemovedFromDepositWhitelist(address strategy);
    event StrategyWhitelisterChanged(address previousAddress, address newAddress);
    event Unpaused(address indexed account, uint256 newPausedStatus);
    event WithdrawalCompleted(
        address indexed depositor, uint96 nonce, address indexed withdrawer, bytes32 withdrawalRoot
    );
    event WithdrawalDelayBlocksSet(uint256 previousValue, uint256 newValue);
    event WithdrawalQueued(
        address depositor, uint96 nonce, address withdrawer, address delegatedAddress, bytes32 withdrawalRoot
    );

    struct QueuedWithdrawal {
        address[] strategies;
        uint256[] shares;
        address depositor;
        WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    struct WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    function DEPOSIT_TYPEHASH() external view returns (bytes32);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function DOMAIN_TYPEHASH() external view returns (bytes32);
    function MAX_WITHDRAWAL_DELAY_BLOCKS() external view returns (uint256);
    function addStrategiesToDepositWhitelist(address[] memory strategiesToWhitelist) external;
    function beaconChainETHSharesToDecrementOnWithdrawal(address) external view returns (uint256);
    function beaconChainETHStrategy() external view returns (address);
    function calculateWithdrawalRoot(QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);
    function completeQueuedWithdrawal(
        QueuedWithdrawal memory queuedWithdrawal,
        address[] memory tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external;
    function completeQueuedWithdrawals(
        QueuedWithdrawal[] memory queuedWithdrawals,
        address[][] memory tokens,
        uint256[] memory middlewareTimesIndexes,
        bool[] memory receiveAsTokens
    ) external;
    function delegation() external view returns (address);
    function depositBeaconChainETH(address staker, uint256 amount) external;
    function depositIntoStrategy(address strategy, address token, uint256 amount) external returns (uint256 shares);
    function depositIntoStrategyWithSignature(
        address strategy,
        address token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);
    function eigenPodManager() external view returns (address);
    function getDeposits(address depositor) external view returns (address[] memory, uint256[] memory);
    function initialize(
        address initialOwner,
        address initialStrategyWhitelister,
        address _pauserRegistry,
        uint256 initialPausedStatus,
        uint256 _withdrawalDelayBlocks
    ) external;
    function nonces(address) external view returns (uint256);
    function numWithdrawalsQueued(address) external view returns (uint256);
    function owner() external view returns (address);
    function pause(uint256 newPausedStatus) external;
    function pauseAll() external;
    function paused(uint8 index) external view returns (bool);
    function paused() external view returns (uint256);
    function pauserRegistry() external view returns (address);
    function queueWithdrawal(
        uint256[] memory strategyIndexes,
        address[] memory strategies,
        uint256[] memory shares,
        address withdrawer,
        bool undelegateIfPossible
    ) external returns (bytes32);
    function recordOvercommittedBeaconChainETH(
        address overcommittedPodOwner,
        uint256 beaconChainETHStrategyIndex,
        uint256 amount
    ) external;
    function removeStrategiesFromDepositWhitelist(address[] memory strategiesToRemoveFromWhitelist) external;
    function renounceOwnership() external;
    function setPauserRegistry(address newPauserRegistry) external;
    function setStrategyWhitelister(address newStrategyWhitelister) external;
    function setWithdrawalDelayBlocks(uint256 _withdrawalDelayBlocks) external;
    function slashQueuedWithdrawal(
        address recipient,
        QueuedWithdrawal memory queuedWithdrawal,
        address[] memory tokens,
        uint256[] memory indicesToSkip
    ) external;
    function slashShares(
        address slashedAddress,
        address recipient,
        address[] memory strategies,
        address[] memory tokens,
        uint256[] memory strategyIndexes,
        uint256[] memory shareAmounts
    ) external;
    function slasher() external view returns (address);
    function stakerStrategyList(address, uint256) external view returns (address);
    function stakerStrategyListLength(address staker) external view returns (uint256);
    function stakerStrategyShares(address, address) external view returns (uint256);
    function strategyIsWhitelistedForDeposit(address) external view returns (bool);
    function strategyWhitelister() external view returns (address);
    function transferOwnership(address newOwner) external;
    function undelegate() external;
    function unpause(uint256 newPausedStatus) external;
    function withdrawalDelayBlocks() external view returns (uint256);
    function withdrawalRootPending(bytes32) external view returns (bool);
}