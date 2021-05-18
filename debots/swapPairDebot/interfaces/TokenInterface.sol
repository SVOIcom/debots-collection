pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

struct ITONTokenWalletDetails {
    address root_address;
    TvmCell code;
    uint256 wallet_public_key;
    address owner_address;
    uint128 balance;

    address receive_callback;
    address bounced_callback;
    bool allow_non_notifiable;
}

struct IRootTokenContractDetails {
    bytes name;
    bytes symbol;
    uint8 decimals;
    TvmCell wallet_code;
    uint256 root_public_key;
    address root_owner_address;
    uint128 total_supply;
}

interface ITIP3Token {
    function balance(uint32 _answer_id) external view returns (uint128);
    function getDetails(uint32 _answer_id) external view returns (ITONTokenWalletDetails);
    function transfer(address to, uint128 tokens, uint128 grams, address send_gas_to, bool notify_receiver, TvmCell payload) external;
}

interface ITIP3Root {
    function getDetails(uint32 _answer_id) external view returns (IRootTokenContractDetails);
}

interface IMultisig {
    function sendTransaction(address dest, uint128 value, bool bounce, uint8 flags, TvmCell payload) external;
}