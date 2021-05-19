pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../interfaces/TokenInterface.sol";
import "../interfaces/SwapPairInterface.sol";

abstract contract TIP3WalletsDatabase {
    struct TIP3WalletInfo {
        address root_address;
        address wallet_address;
        uint256 wallet_public_key;
        address owner_address;
        uint128 balance;
        bytes symbol;
        uint8 decimals;
        ManageType manageType;
    }

    enum ManageType { MANAGE_WITH_KEYPAIR, MANAGE_WITH_MULTISIG }

    // Root addresses to wallets
    mapping (address => TIP3WalletInfo) tip3Wallets;

    function addTIP3(address rootAddress, TIP3WalletInfo tip3Info) public {
        if (!tip3Wallets.exists(rootAddress)) {
            tip3Wallets.add(rootAddress, tip3Info);
        }
    }

    function removeTIP3(address rootAddress) public {
        if (tip3Wallets.exists(rootAddress)) {
            delete tip3Wallets[rootAddress];
        }
    }

    function replaceTIP3(address rootAddress, TIP3WalletInfo tip3Info) public {
        if (tip3Wallets.exists(rootAddress)) {
            tip3Wallets.replace(rootAddress, tip3Info);
        } else {
            addTIP3(rootAddress, tip3Info);
        }
    }

    function transformToTIP3WalletInfo(
        ITONTokenWalletDetails receivedTIP3WalletInfo, 
        IRootTokenContractDetails receivedTIP3RootInfo, 
        address tip3WalletAddress
    ) public pure returns (TIP3WalletInfo) {
        return TIP3WalletInfo(
            receivedTIP3WalletInfo.root_address,
            tip3WalletAddress,
            receivedTIP3WalletInfo.wallet_public_key,
            receivedTIP3WalletInfo.owner_address,
            receivedTIP3WalletInfo.balance,
            receivedTIP3RootInfo.symbol,
            receivedTIP3RootInfo.decimals,
            receivedTIP3WalletInfo.owner_address.value == 0 ? ManageType.MANAGE_WITH_KEYPAIR : ManageType.MANAGE_WITH_MULTISIG
        );
    }
}