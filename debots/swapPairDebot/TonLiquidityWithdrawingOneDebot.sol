pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../../deinterfaces/AddressInput/AddressInput.sol";
import "../../deinterfaces/AmountInput/AmountInput.sol";
import "../../deinterfaces/ConfirmInput/ConfirmInput.sol";
import "../../deinterfaces/Menu/Menu.sol";
import "../../deinterfaces/Terminal/Terminal.sol";

import "../../deinterfaces/IDebot.sol";
import "../../deinterfaces/IUpgradable.sol";

import "./helperContracts/TIP3WalletsDatabase.sol";
import "./helperContracts/SwapPairDatabase.sol";
import "./helperContracts/StringContract.sol";

import "./interfaces/TokenInterface.sol";
import "./lib/Constants.sol";

contract SwapPairExplorer is Debot, Upgradable, TIP3WalletsDatabase {

    uint128 constant maxUint128 = 340282366920938463463374607431768211455;

    address tmpTIP3WalletAddress;
    address tmpRootAddress;
    ITONTokenWalletDetails tmpWalletInfoStorage;
    uint128 lpTokenAmount;
    bytes symbol1; bytes symbol2;
    uint8 decimals1; uint8 decimals2;
    TvmCell payload;
    address currentSwapPair;

    SwapPairInfo spi;

    //========================================
    //
    constructor() public 
    {
        tvm.accept();
    }
    
	//========================================
    //
	function getRequiredInterfaces() public pure returns (uint256[] interfaces) 
    {
        return [Terminal.ID, AddressInput.ID, ConfirmInput.ID, AmountInput.ID, Menu.ID];
	}

    //========================================
    //
    function getDebotInfo() public functionID(0xDEB) view returns(
        string name,     string version, string publisher, string key,  string author,
        address support, string hello,   string language,  string dabi, bytes icon
    ) {
        name      = "TonSwap Liquidity withdrawing via one token debot";
        version   = "0.1.0";
        publisher = "SVOI.dev team";
        key       = "SVOI.dev team's TonSwap debot";
        author    = "SVOI.dev team";
        support   = address.makeAddrStd(0, 0);
        hello     = "Hi there! :)";
        language  = "en";
        dabi      = m_debotAbi.hasValue() ? m_debotAbi.get() : "";
        icon      = m_icon.hasValue()     ? m_icon.get()     : "";
    }

    //========================================
    /// @notice Define DeBot version and title here.
    function getVersion() public override returns (string name, uint24 semver) {
        (name, semver) = ("TonSwap Liquidity withdrawing via one token debot", _version(0, 1, 0));
    }

    function _version(uint24 major, uint24 minor, uint24 fix) private pure inline returns (uint24) {
        return (major << 16) | (minor << 8) | (fix);
    }    

    //========================================
    // Implementation of Upgradable
    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }

    //========================================
    /// @notice Entry point function for DeBot.    
    function start() public override {
        mainMenu(0);
    }

    function mainMenu(uint32 index) public {
        MenuItem[] mi;
        mi.push(MenuItem("Withdraw liquidity", "", tvm.functionId(withdrawLiquidtiyOneEntryPoint)));
        mi.push(MenuItem("Add token wallets", "Add token wallets for iteration with swap pair or get it's status", tvm.functionId(addWalletEntryPoint)));
        mi.push(MenuItem("About SVOI dev", "Information about SVOI dev", tvm.functionId(aboutInfoEntryPoint)));
        Menu.select("Choose action", "", mi);
    }

    //========================================
    function withdrawLiquidtiyOneEntryPoint(uint32 index) public {
        AddressInput.get(tvm.functionId(receiveSwapPairAddress), "Input swap pair address:");
    }

    function receiveSwapPairAddress(address value) public {
        currentSwapPair = value;
        optional(uint256) pubkey; 
        ISwapPair(currentSwapPair).getPairInfo{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: tvm.functionId(receiveSwapPairInfo),
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(0);
    }

    function receiveSwapPairInfo(SwapPairInfo spi_) public {
        spi = spi_;
        getTIP3RootDetails(spi.tokenRoot1, tvm.functionId(receiveFirstTIP3Info));
    }

    function receiveFirstTIP3Info(IRootTokenContractDetails tri) public {
        symbol1 = tri.symbol;
        decimals1 = tri.decimals;
        getTIP3RootDetails(spi.tokenRoot2, tvm.functionId(receiveSecondTIP3Info));
    }

    function receiveSecondTIP3Info(IRootTokenContractDetails tri) public {
        symbol2 = tri.symbol;
        decimals2 = tri.decimals;
        liquidityWithrawOneContinuePoint();
    }

    function liquidityWithrawOneContinuePoint() public {
        if (!tip3Wallets.exists(spi.lpTokenRoot)) {
            Terminal.print(0, format("Add wallet for {} LP token please", spi.swapPairLPTokenName));
            addTIP3WalletEntryPoint(0);
        } else {
            MenuItem[] mi;
            mi.push(MenuItem(format("{}", symbol1), "", tvm.functionId(getTokenIndex)));
            mi.push(MenuItem(format("{}", symbol2), "", tvm.functionId(getTokenIndex)));
            Menu.select("Choose token to withdraw liquidity into:", "", mi);
        }
    }

    function getTokenIndex(uint32 index) public {
        tmpRootAddress = index == 0 ? spi.tokenRoot1 : spi.tokenRoot2;
        if (!tip3Wallets.exists(tmpRootAddress)) {
            printAndAddToken(tmpRootAddress == spi.tokenRoot1? symbol1 : symbol2);
        } else {
            AmountInput.get(
                tvm.functionId(receiveLPTokenAmount), 
                format("Input token amount of {} LP token to withdraw", spi.swapPairLPTokenName), 
                0, 
                1, 
                maxUint128
            );
        }
    }

    function receiveLPTokenAmount(uint128 value) public {
        lpTokenAmount = value;
        getPayloadForLiquidityWithdrawing();
    }

    function getPayloadForLiquidityWithdrawing() public {
        optional(uint256) pubkey; 
        ISwapPair(currentSwapPair).createWithdrawLiquidityOneTokenPayload{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: tvm.functionId(receivePayloadForLPWithdrawing),
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(tmpRootAddress, tip3Wallets[tmpRootAddress].wallet_address);
    }

    function receivePayloadForLPWithdrawing(TvmCell payload_) public {
        if (tip3Wallets[spi.lpTokenRoot].manageType == ManageType.MANAGE_WITH_KEYPAIR) {
            optional(uint256) pubkey = 0;
            ITIP3Token(tip3Wallets[spi.lpTokenRoot].wallet_address).transfer{
                abiVer: 2,
                extMsg: true,
                sign: true,
                callbackId: 0,
                onErrorId: tvm.functionId(onError),
                time: uint64(now),
                expire: 0,
                pubkey: pubkey
            }(
                spi.lpTokenWallet, lpTokenAmount, 0.5 ton, address.makeAddrStd(0, 0), true, payload_
            );
        } else {
            TvmCell payloadForTIP;
            payloadForTIP = tvm.encodeBody(
                ITIP3Token.transfer, 
                spi.lpTokenWallet, 
                lpTokenAmount, 0.5 ton, address.makeAddrStd(0, 0), true, payload_
            );
            optional(uint256) pubkey = 0;
            IMultisig(tip3Wallets[spi.lpTokenRoot].owner_address).sendTransaction{
                abiVer: 2,
                extMsg: true,
                sign: true,
                callbackId: 0,
                onErrorId: tvm.functionId(onError),
                time: uint64(now),
                expire: 0,
                pubkey: pubkey
            }(tip3Wallets[spi.lpTokenRoot].wallet_address, 0.6 ton, true, 1, payloadForTIP);
        }

        Terminal.print(tvm.functionId(returnToMainMenu), "Liquidity withdrawing in process. Returning to main menu.");
    }

    function printAndAddToken(bytes symbol) private {
        Terminal.print(0, format("Wallet for {} does not exists. Please add it", symbol));
        addTIP3WalletEntryPoint(0);
    }


    function returnToMainMenu() public {
        mainMenu(0);
    }

    //========================================
    /// @notice TIP3 manage functionality goes here
    function addWalletEntryPoint(uint32 index) public {
        index = 0;

        MenuItem[] mi;
        mi.push(MenuItem("Add TIP-3 wallet", "", tvm.functionId(addTIP3WalletEntryPoint)));
        mi.push(MenuItem("Show your wallets", "", tvm.functionId(showTIP3Wallets)));
        mi.push(MenuItem("Update balances", "", tvm.functionId(updateWalletBalances)));
        mi.push(MenuItem("Exit to main menu", "", tvm.functionId(mainMenu)));
        Menu.select("", "", mi);
    }

    function addTIP3WalletEntryPoint(uint32 index) public {        
        AddressInput.get(tvm.functionId(getTIP3Address), "Input your TIP-3 wallet address:");
    }
    
    function getTIP3Address(address value) public {
        tmpTIP3WalletAddress = value;
        getTIP3WalletDetails(value, tvm.functionId(receiveTIP3WalletInfo));
    }

    function receiveTIP3WalletInfo(ITONTokenWalletDetails walletInfo) public {
        tmpWalletInfoStorage = walletInfo;
        getTIP3RootDetails(walletInfo.root_address, tvm.functionId(receiveTIP3RootInfo));
    }

    function receiveTIP3RootInfo(IRootTokenContractDetails rootInfo) public {
        Terminal.print(0, buildWalletInfo(transformToTIP3WalletInfo(tmpWalletInfoStorage, rootInfo, tmpTIP3WalletAddress)));
        replaceTIP3(tmpWalletInfoStorage.root_address, transformToTIP3WalletInfo(tmpWalletInfoStorage, rootInfo, tmpTIP3WalletAddress));
        cleanUpTmpVars();
        Terminal.print(tvm.functionId(returnToTIP3ManageEntryPoint), "Wallet added");
    }

    function returnToTIP3ManageEntryPoint() public {
        addWalletEntryPoint(0);
    }

    function getTIP3WalletDetails(address wallet, uint32 callbackFunctionId) public pure {
        optional(uint256) pubkey;
        ITIP3Token(wallet).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: callbackFunctionId,
            onErrorId: 0xEEE,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(callbackFunctionId);
    }

    function getTIP3RootDetails(address root, uint32 callbackFunctionId) public pure {
        optional(uint256) pubkey;
        ITIP3Root(root).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: callbackFunctionId,
            onErrorId: 0xEEE,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(callbackFunctionId);
    }

    function buildWalletInfo(TIP3WalletInfo walletInfo) private pure returns(string) {
        string tmpString;
        uint8 decimals = walletInfo.decimals == 0 ? 1 : walletInfo.decimals;
        tmpString.append(format("{} token wallet\n", walletInfo.symbol));
        tmpString.append(format("Balance: {}.{}\n", walletInfo.balance / 10**uint(decimals), walletInfo.balance % 10**uint(decimals)));
        tmpString.append(format("Wallet Address: {}\n", walletInfo.wallet_address));
        if (walletInfo.manageType == ManageType.MANAGE_WITH_KEYPAIR) {
            tmpString.append(format("Pubkey: {}\n", walletInfo.wallet_public_key));
        } else {
            tmpString.append(format("Multisig: {}\n", walletInfo.owner_address));
        }
        return tmpString;
    }

    function showTIP3Wallets(uint32 index) public {
        for ((, TIP3WalletInfo walletInfo) : tip3Wallets) {
            Terminal.print(0, buildWalletInfo(walletInfo));
        }

        returnToTIP3ManageEntryPoint();
    }

    function updateWalletBalances(uint32 index) public {
        for ((, TIP3WalletInfo walletInfo) : tip3Wallets) {
            getTIP3WalletDetails(walletInfo.wallet_address, tvm.functionId(receiveWalletBalancesUpdate));
        }
        Terminal.print(tvm.functionId(returnToTIP3ManageEntryPoint), "Wallet balances will be updated in a minute.");
    }

    function receiveWalletBalancesUpdate(ITONTokenWalletDetails twi) public {
        tip3Wallets[twi.root_address].balance = twi.balance;
    }

    function cleanUpTmpVars() private {
        delete tmpTIP3WalletAddress;
        delete tmpWalletInfoStorage;
    }

    function aboutInfoEntryPoint(uint32 index) public {
        Terminal.print(0, "SVOI.dev team are developing products for Free TON.");
        Terminal.print(0, "TONSwap - liquidity pool based exchange https://tonswap.com");
        Terminal.print(0, "TONWallet - browser extention for wallets management https://https://tonwallet.io/");
        Terminal.print(0, "Our telegram channel: https://t.me/tonswap");
        mainMenu(0);
    }

    //========================================
    /// @notice Error functionality goes here
    function onError(uint32 sdkError, uint32 exitCode) functionID(0xEEE) public {
        Terminal.print(0, format("SdkError: {}, exitCode: {}", sdkError, exitCode));
        mainMenu(0);
    }
}