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

    address tmpRootAddress;
    address tmpTIP3WalletAddress;
    ITONTokenWalletDetails tmpWalletInfoStorage;
    uint128 amountForLPWithdraw;
    bytes symbol1; bytes symbol2;
    uint8 decimals1; uint8 decimals2;
    TvmCell payload;
    address currentSwapPair;
    bool lpWalletDoesNotExists = false;

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
        name      = "TonSwap debot for liquidity prividing via one token";
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
        (name, semver) = ("TonSwap debot for liquidity prividing via one token", _version(0, 1, 0));
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
        mi.push(MenuItem("Provide liquidity with one token", "", tvm.functionId(swapEntryPoint)));
        mi.push(MenuItem("Add token wallets", "Add token wallets for iteration with swap pair or get it's status", tvm.functionId(addWalletEntryPoint)));
        mi.push(MenuItem("About SVOI dev", "Information about SVOI dev", tvm.functionId(aboutInfoEntryPoint)));
        Menu.select("Choose action", "", mi);
    }

    //========================================
    function swapEntryPoint(uint32 index) public {
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

    function printAndAddToken(bytes symbol) private {
        Terminal.print(0, format("Wallet for {} does not exists. Please add it", symbol));
        addTIP3WalletEntryPoint(0);
    }

    function receiveFirstTIP3Info(IRootTokenContractDetails tri) public {
        symbol1 = tri.symbol;
        decimals1 = tri.decimals;
        getTIP3RootDetails(spi.tokenRoot2, tvm.functionId(receiveSecondTIP3Info));
    }

    function receiveSecondTIP3Info(IRootTokenContractDetails tri) public {
        symbol2 = tri.symbol;
        decimals2 = tri.decimals;
        liquidityProvideOneContinuePoint();
    }

    function liquidityProvideOneContinuePoint() public {
        MenuItem[] mi;
        mi.push(MenuItem(format("{}", symbol1), "", tvm.functionId(getTokenIndex)));
        mi.push(MenuItem(format("{}", symbol2), "", tvm.functionId(getTokenIndex)));
        Menu.select("Choose token:", "", mi);
    }

    function getTokenIndex(uint32 index) public {
        tmpRootAddress = index == 0 ? spi.tokenRoot1 : spi.tokenRoot2;
        if (!tip3Wallets.exists(tmpRootAddress)) {
            printAndAddToken(index == 0 ? symbol1 : symbol2);
        } if (!tip3Wallets.exists(spi.lpTokenRoot)) {
            ConfirmInput.get(tvm.functionId(confirmNoLPWallet), "Please confirm that you don't have LP wallet:");
        } else {
            getAmountForLPProviding();
        }
    }

    function confirmNoLPWallet(bool value) public {
        lpWalletDoesNotExists = value;
        if (!value) {
            Terminal.print(0, "Add wallet for LP token please");
            addTIP3WalletEntryPoint(0);
        } else {
            getAmountForLPProviding();
        }
    }

    function getAmountForLPProviding() public {
        AmountInput.get(
            tvm.functionId(getTokenAmount), 
            "Input token amount for liquidity providing", 
            tmpRootAddress == spi.tokenRoot1 ? decimals1 : decimals2, 
            1, 
            maxUint128 / 10**uint128(tmpRootAddress == spi.tokenRoot1 ? decimals1 : decimals2)
        );
    }

    function getTokenAmount(uint128 value) public {
        amountForLPWithdraw = value;

        optional(uint256) pubkey; 
        ISwapPair(currentSwapPair).createProvideLiquidityOneTokenPayload{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: tvm.functionId(getPayloadForLiquidityProviding),
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(lpWalletDoesNotExists ? address.makeAddrStd(0, 0) : tip3Wallets[spi.lpTokenRoot].wallet_address);
    }

    function getPayloadForLiquidityProviding(TvmCell payload_) public {
        if (tip3Wallets[tmpRootAddress].manageType == ManageType.MANAGE_WITH_KEYPAIR) {
            optional(uint256) pubkey = 0;
            ITIP3Token(tip3Wallets[tmpRootAddress].wallet_address).transfer{
                abiVer: 2,
                extMsg: true,
                sign: true,
                callbackId: 0,
                onErrorId: tvm.functionId(onError),
                time: uint64(now),
                expire: 0,
                pubkey: pubkey
            }(
                tmpRootAddress == spi.tokenRoot1 ? spi.tokenWallet1 : spi.tokenWallet2, 
                amountForLPWithdraw, 0.2 ton, address.makeAddrStd(0, 0), true, payload_
            );
        } else {
            TvmCell payloadForTIP;
            payloadForTIP = tvm.encodeBody(
                ITIP3Token.transfer, 
                tmpRootAddress == spi.tokenRoot1 ? spi.tokenWallet1 : spi.tokenWallet2, 
                amountForLPWithdraw, 0.2 ton, address.makeAddrStd(0, 0), true, payload_
            );
            optional(uint256) pubkey = 0;
            IMultisig(tip3Wallets[tmpRootAddress].owner_address).sendTransaction{
                abiVer: 2,
                extMsg: true,
                sign: true,
                callbackId: 0,
                onErrorId: tvm.functionId(onError),
                time: uint64(now),
                expire: 0,
                pubkey: pubkey
            }(tip3Wallets[tmpRootAddress].wallet_address, 0.2 ton, true, 1, payloadForTIP);
        }
        lpWalletDoesNotExists = false;
        Terminal.print(tvm.functionId(returnToMainMenu), "Providing liquidity in process. Returning to main menu.");
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