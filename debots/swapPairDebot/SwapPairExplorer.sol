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

import "./helperContracts/SwapPairDatabase.sol";
import "./helperContracts/StringContract.sol";

import "./interfaces/TokenInterface.sol";

contract SwapPairExplorer is Debot, Upgradable, SwapPairDatabase {

    uint32 currentSwapPair;
    bytes symbol1; bytes symbol2;
    uint8 decimals1; uint8 decimals2;
    address firstTIP3Address; address secondTIP3Address;
    TvmCell payload;

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
        name      = "Explorer for TONSwap project";
        version   = "0.1.0";
        publisher = "SVOI.dev team";
        key       = "SVOI.dev team's explorer for TONSwap";
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
        (name, semver) = ("Explorer for TONSwap project", _version(0, 1, 0));
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
        requestSwapPairsList();
        mainMenu(0);
    }

    function mainMenu(uint32 index) public {
        MenuItem[] mi;
        mi.push(MenuItem("Explore swap pairs", "Opens explorer with information about swap pairs", tvm.functionId(explorerEntryPoint)));
        mi.push(MenuItem("Add new swap pair", "Add swap pair for two tokens", tvm.functionId(addSwapPairEntryPoint)));
        mi.push(MenuItem("Refresh swap pair list", "It may take several minutes", tvm.functionId(refreshSwapPairList)));
        mi.push(MenuItem("About SVOI dev", "Information about SVOI dev", tvm.functionId(aboutInfoEntryPoint)));
        Menu.select("Choose action", "", mi);
    }

    //========================================
    /// @notice Explorer functionality goes here
    function explorerEntryPoint(uint32 index) public {
        chooseSwapPair(tvm.functionId(getFirstRootInfo));
    }

    function chooseSwapPair(uint32 functionId) public {
        MenuItem[] mi;

        uint32 i = 0;
        for ((, SwapPairInfo spi) : swapPairs) {
            mi.push(MenuItem(spi.swapPairLPTokenName, "", functionId));
            swapPairsNumberToAddress[i] = spi.swapPairAddress;
            i++;
        }
        mi.push(MenuItem("Exit to main menu", "", tvm.functionId(mainMenu)));
        Menu.select("Choose swap pair:", "", mi);
    }

    function getFirstRootInfo(uint32 index) public {
        currentSwapPair = index;
        getTIP3RootDetails(swapPairs[swapPairsNumberToAddress[currentSwapPair]].tokenRoot1, tvm.functionId(receiveFirstRootInfo));
    }

    function receiveFirstRootInfo(IRootTokenContractDetails rootInfo) public {
        symbol1 = rootInfo.symbol;
        decimals1 = rootInfo.decimals;
        getSecondRootInfo();
    }

    function getSecondRootInfo() public view {
        getTIP3RootDetails(swapPairs[swapPairsNumberToAddress[currentSwapPair]].tokenRoot2, tvm.functionId(receiveSecondRootInfo));
    }

    function receiveSecondRootInfo(IRootTokenContractDetails rootInfo) public {
        symbol2 = rootInfo.symbol;
        decimals2 = rootInfo.decimals;
        getSwapPairInfo();
    }

    function getSwapPairInfo() public view {
        optional(uint256) pubkey;
        ISwapPair(swapPairs[swapPairsNumberToAddress[currentSwapPair]].swapPairAddress).getCurrentExchangeRate{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: tvm.functionId(printSwapPairInfo),
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(0);
    }

    function printSwapPairInfo(LiquidityPoolsInfo lpi) public {
        Terminal.print(0, format("Address: {}", lpi.swapPairAddress));
        Terminal.print(0, format("{} token pool: {}.{}", symbol1, lpi.lp1 / 10**uint(decimals1), lpi.lp1 % 10**uint(decimals1)));
        Terminal.print(0, format("{} token pool: {}.{}", symbol2, lpi.lp2 / 10**uint(decimals1), lpi.lp2 % 10**uint(decimals1)));
        Terminal.print(0, format("LP tokens minted: {}", lpi.lpTokensMinted));
        chooseSwapPair(tvm.functionId(getFirstRootInfo));
    }

    function addSwapPairEntryPoint(uint32 index) public {
        AddressInput.get(tvm.functionId(getFirstTIP3Address), "Input first tip-3 address:");
    }

    function getFirstTIP3Address(address value) public {
        firstTIP3Address = value;
        AddressInput.get(tvm.functionId(getSecondTIP3Address), "Input second tip-3 address:");
    }

    function getSecondTIP3Address(address value) public {
        secondTIP3Address = value;
        Terminal.print(0, "Checking if this swap pair exists");
        optional(uint256) pubkey;
        IRootSwapPair(rootAddress).checkIfPairExists{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: tvm.functionId(swapPairExistsCheck),
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(firstTIP3Address, secondTIP3Address);
    }

    function swapPairExistsCheck(bool value0) public {
        if (value0) {
            Terminal.print(0, "Swap pair already exists. Returning to main menu.");
            mainMenu(0);
        } else {
            Terminal.print(0, "Swap pair does not exist. Proceeding to swap pair creation");
            MenuItem[] mi;
            mi.push(MenuItem("Send message via multisig", "", tvm.functionId(sendMessageToRootSwapPair)));
            mi.push(MenuItem("Send message via KeyPair", "", tvm.functionId(sendMessageToRootSwapPair)));
            Menu.select("Choose method:", "", mi);
        }
    }

    function sendMessageToRootSwapPair(uint32 index) public {
        if (index == 0) {
            payload = tvm.encodeBody(IRootSwapPair.deploySwapPair, firstTIP3Address, secondTIP3Address);
            AddressInput.get(tvm.functionId(getMultisigAddress), "Input your multisig address:");
        } else {
            optional(uint256) pubkey;
            IRootSwapPair(rootAddress).deploySwapPair{
                abiVer: 2,
                extMsg: true,
                sign: true,
                callbackId: tvm.functionId(showSwapPairAddress),
                onErrorId: tvm.functionId(onError),
                time: uint64(now),
                expire: 0,
                pubkey: pubkey
            }(firstTIP3Address, secondTIP3Address);
        }
    }

    function getMultisigAddress(address value) public {
        optional(uint256) pubkey = 0;
        IMultisig(value).sendTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            callbackId: 0,
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(rootAddress, 11 ton, true, 1, payload);
        requestSwapPairsList();
        mainMenu(0);
    }

    function showSwapPairAddress(address futureSwapPairAddress) public {
        Terminal.print(0, format("Future swap pair address: {}", futureSwapPairAddress));
        mainMenu(0);
    }

    function refreshSwapPairList(uint32 index) public {
        requestSwapPairsList();
        Terminal.print(0, "Refreshing swap pair list...");
        mainMenu(0);
    }

    function aboutInfoEntryPoint(uint32 index) public {
        Terminal.print(0, "SVOI.dev team are developing products for Free TON.");
        Terminal.print(0, "TONSwap - liquidity pool based exchange https://tonswap.com");
        Terminal.print(0, "TONWallet - browser extention for wallets management https://https://tonwallet.io/");
        Terminal.print(0, "Our telegram channel: https://t.me/tonswap");
        mainMenu(0);
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("SdkError: {}, exitCode: {}", sdkError, exitCode));
        mainMenu(0);
    }

    function getTIP3RootDetails(address root, uint32 callbackFunctionId) private pure {
        optional(uint256) pubkey;
        ITIP3Root(root).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: callbackFunctionId,
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(callbackFunctionId);
    }
}