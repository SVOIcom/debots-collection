pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

struct SwapPairInfo {
    address rootContract;           // address of swap pair deployer address
    address tokenRoot1;             // address of first TIP-3 token root
    address tokenRoot2;             // address of second TIP-3 token root
    address lpTokenRoot;            // address of deployed LP token root
    address tokenWallet1;           // address of first TIP-3 token wallet
    address tokenWallet2;           // address of second TIP-3 token wallet
    address lpTokenWallet;          // address of deployed LP token wallet
    uint256 deployTimestamp;        // when the contract was deployed
    address swapPairAddress;        // address of swap pair
    uint256 uniqueId;               // unique id of swap pair
    uint32  swapPairCodeVersion;    // code version of swap pair. can be upgraded using root contract
    bytes   swapPairLPTokenName;    // name of swap pair LP token
}

struct LiquidityPoolsInfo {
    address swapPairAddress; // Address of current swap pair
    uint128 lp1;             // volume of first LP
    uint128 lp2;             // volume of second LP
    uint256 lpTokensMinted;  // amount of minted LP tokens 
}

interface ISwapPair {
    function createSwapPayload(address sendTokensTo) external pure returns (TvmCell);
    function createProvideLiquidityPayload(address tip3Address) external pure returns (TvmCell);
    function createProvideLiquidityOneTokenPayload(address tip3Address) external pure returns (TvmCell);
    function createWithdrawLiquidityPayload(
        address tokenRoot1,
        address tokenWallet1,
        address tokenRoot2,
        address tokenWallet2
    ) external pure returns (TvmCell);
    function createWithdrawLiquidityOneTokenPayload(address tokenRoot, address userWallet) external pure returns (TvmCell);

    function getCurrentExchangeRate(uint32 _answer_id) external view returns (LiquidityPoolsInfo lpi);
    function getPairInfo(uint32 _answer_id) external view returns (SwapPairInfo info);
}

interface IRootSwapPair {
    function getAllSwapPairsID() external view returns (uint256[] ids);
    function getPairInfoByID(uint256 uniqueID) external view returns(SwapPairInfo);
    function deploySwapPair(address tokenRootContract1, address tokenRootContract2) external returns (address);
    function checkIfPairExists(address tokenRootContract1, address tokenRootContract2) external view returns (bool value0);
}