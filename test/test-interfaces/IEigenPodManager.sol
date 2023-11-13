interface IEigenPodManager {
    event BeaconChainETHDeposited(address indexed podOwner, uint256 amount);
    event BeaconOracleUpdated(address indexed newOracleAddress);
    event Initialized(uint8 version);
    event MaxPodsUpdated(uint256 previousValue, uint256 newValue);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account, uint256 newPausedStatus);
    event PauserRegistrySet(address pauserRegistry, address newPauserRegistry);
    event PodDeployed(address indexed eigenPod, address indexed podOwner);
    event Unpaused(address indexed account, uint256 newPausedStatus);

    function beaconChainOracle() external view returns (address);
    function createPod() external;
    function eigenPodBeacon() external view returns (address);
    function ethPOS() external view returns (address);
    function getBeaconChainStateRoot(uint64 blockNumber) external view returns (bytes32);
    function getPod(address podOwner) external view returns (address);
    function hasPod(address podOwner) external view returns (bool);
    function initialize(
        uint256 _maxPods,
        address _beaconChainOracle,
        address initialOwner,
        address _pauserRegistry,
        uint256 _initPausedStatus
    ) external;
    function maxPods() external view returns (uint256);
    function numPods() external view returns (uint256);
    function owner() external view returns (address);
    function ownerToPod(address) external view returns (address);
    function pause(uint256 newPausedStatus) external;
    function pauseAll() external;
    function paused(uint8 index) external view returns (bool);
    function paused() external view returns (uint256);
    function pauserRegistry() external view returns (address);
    function recordOvercommittedBeaconChainETH(address podOwner, uint256 beaconChainETHStrategyIndex, uint256 amount)
        external;
    function renounceOwnership() external;
    function restakeBeaconChainETH(address podOwner, uint256 amount) external;
    function setMaxPods(uint256 newMaxPods) external;
    function setPauserRegistry(address newPauserRegistry) external;
    function slasher() external view returns (address);
    function stake(bytes memory pubkey, bytes memory signature, bytes32 depositDataRoot) external payable;
    function strategyManager() external view returns (address);
    function transferOwnership(address newOwner) external;
    function unpause(uint256 newPausedStatus) external;
    function updateBeaconChainOracle(address newBeaconChainOracle) external;
    function withdrawRestakedBeaconChainETH(address podOwner, address recipient, uint256 amount) external;
}