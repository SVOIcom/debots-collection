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


// TODO: реализация взаимодействия с контрактами TIP-3:
// [x]: Получение информации о TIP-3
// [ ]: Взаимодействие TIP-3 с контрактами 

contract TonSwapTIP3Debot is Debot, TIP3WalletsDatabase, SwapPairDatabase, StringContract {
    enum CURRENT_OPERATION { SWAP, PROVIDE_LP, PROVIDE_LP_ONE, WITHDRAW_LP, WITHDRAW_LP_ONE }
    address constant addressZero = address.makeAddrStd(0, 0);

    CURRENT_OPERATION currentOperation;
    address tmpTIP3WalletAddress;
    ITONTokenWalletDetails tmpWalletInfoStorage;
    IRootTokenContractDetails tmpRootInfoStorage;
    TIP3WalletInfo tmpDBRecord;

    //========================================
    //
    constructor() public 
    {
        tvm.accept();
    }
    
	//========================================
    //
	function getRequiredInterfaces() public override pure returns (uint256[] interfaces) 
    {
        return [Terminal.ID, AddressInput.ID, ConfirmInput.ID, AmountInput.ID, Menu.ID];
	}

    //========================================
    //
    function getDebotInfo() public override functionID(0xDEB) view returns(
        string name,     string version, string publisher, string key,  string author,
        address support, string hello,   string language,  string dabi, bytes icon
    ) {
        name      = vals[1];
        version   = vals[2];
        publisher = vals[3];
        key       = vals[4];
        author    = vals[5];
        support   = addressZero;
        hello     = vals[6];
        language  = "en";
        dabi      = m_debotAbi.hasValue() ? m_debotAbi.get() : "";
        icon      = m_icon.hasValue()     ? m_icon.get()     : "";
    }

    //========================================
    /// @notice Define DeBot version and title here.
    function getVersion() public override returns (string name, uint24 semver) {
        (name, semver) = (vals[1], _version(0, 1, 0));
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
        delete tip3Wallets;
        delete swapPairs;
        cleanUpTmpVars();
        requestSwapPairsList();
        mainMenu(0);
    }

    function mainMenu(uint32 index) public {
        index = 0;

        MenuItem[] mi;
        mi.push(MenuItem("", "", tvm.functionId(tonswapEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(tip3ManageEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(extraInfoEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(explorerEntryPoint)));
        Menu.select("", "", mi);
    }

    //========================================
    /// @notice TonSwap functionality goes here
    function tonswapEntryPoint(uint32 index) public {
        index = 0;

        chooseSwapPair(tvm.functionId(chooseSwapPairAction));
    }

    function chooseSwapPairAction(uint32 index) public {
        Terminal.print(0, format("Swap pair: {}", swapPairs[swapPairsNumberToAddress[index-1]].swapPairLPTokenName));
        MenuItem[] mi;
        mi.push(MenuItem("", "", tvm.functionId(swapTokensEntyPoint)));
        mi.push(MenuItem("", "", tvm.functionId(provideLiquidityEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(provideLiquidityOneTokenEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(withdrawLiquidityEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(withdrawLiquidityOneTokenEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(returnToMainMenu)));

        Menu.select("", "", mi);

        // mi.push(MenuItem(vals[20], vals[21], tvm.functionId(swapTokensEntyPoint)));
        // mi.push(MenuItem(vals[22], vals[23], tvm.functionId(provideLiquidityEntryPoint)));
        // mi.push(MenuItem(vals[24], vals[25], tvm.functionId(provideLiquidityOneTokenEntryPoint)));
        // mi.push(MenuItem(vals[26], vals[27], tvm.functionId(withdrawLiquidityEntryPoint)));
        // mi.push(MenuItem(vals[28], vals[29], tvm.functionId(withdrawLiquidityOneTokenEntryPoint)));
        // mi.push(MenuItem(vals[30], vals[31], tvm.functionId(returnToMainMenu)));

        // Menu.select(vals[32], vals[33], mi);

    }

    function swapTokensEntyPoint(uint32 index) public {
        index = 0;
        MenuItem[] mi;
        mi.push(MenuItem(
            format("Token-{}", index+1), 
            format("Address: {}:{}", index, index), 
            tvm.functionId(getWalletForSwap))
        );
        mi.push(MenuItem(
            format("Token-{}", index+1), 
            format("Address: {}:{}", index, index), 
            tvm.functionId(getWalletForSwap))
        );
        Menu.select("Choose your wallet:", "", mi);
    }

    function getWalletForSwap(uint32 index) public {
        AmountInput.get(tvm.functionId(performSwapOperation),  "Input token amount for swap:", 9, 0, 10);
    }

    function performSwapOperation(uint128 value) public {
        Terminal.print(tvm.functionId(returnToSwapMenu), "Great! Swap completed");
    }

    function provideLiquidityEntryPoint(uint32 index) public {
        AmountInput.get(tvm.functionId(getFirstTokenAmount),  format(" ${} token:", index+1), 9, 0, 10);
        AmountInput.get(tvm.functionId(getSecondTokenAmount),  format(" ${} token:", index+2), 9, 0, 10);
        Terminal.print(tvm.functionId(performLiquidityProvidingOperation), " operation");
    }

    function performLiquidityProvidingOperation() public {
        Terminal.print(tvm.functionId(returnToSwapMenu), "");
    }

    function provideLiquidityOneTokenEntryPoint(uint32 index) public {
        AmountInput.get(tvm.functionId(getFirstTokenAmount),  format(" ${} token:", index+1), 9, 0, 10);
        Terminal.print(tvm.functionId(performLiquidityProvidingOneTokenOperation), " operation");
    }

    function performLiquidityProvidingOneTokenOperation() public {
        Terminal.print(tvm.functionId(returnToSwapMenu), " completed");
    }

    function withdrawLiquidityEntryPoint(uint32 index) public {
        AmountInput.get(tvm.functionId(getFirstTokenAmount),  format(" ${} token:", index+1), 9, 0, 10);
        Terminal.print(tvm.functionId(performLiquidityWithdrawingOperation), " operation");
    }

    function performLiquidityWithdrawingOperation() public {
        Terminal.print(tvm.functionId(returnToSwapMenu), "");
    }

    function withdrawLiquidityOneTokenEntryPoint(uint32 index) public {
        AmountInput.get(tvm.functionId(getFirstTokenAmount),  format(" ${} token:", index+1), 9, 0, 10);
        MenuItem[] mi;
        mi.push(MenuItem(
            format(" {}", index+1), 
            format(": {}:{}", index, index), 
            tvm.functionId(getWalletForLPWithdraw))
        );
        mi.push(MenuItem(
            format("", index+1), 
            format("", index, index), 
            tvm.functionId(getWalletForLPWithdraw))
        );
        Menu.select("", "", mi);
    }

    function getWalletForLPWithdraw(uint32 index) public {
        Terminal.print(0, format("", index));
        Terminal.print(0, "");
        performLiquidityWithdrawingOneTokenOperation();
    }

    function performLiquidityWithdrawingOneTokenOperation() public {
        Terminal.print(tvm.functionId(returnToSwapMenu), "");
    }

    function getFirstTokenAmount(uint128 value) public pure {
        value = 0;
    }

    function getSecondTokenAmount(uint128 value) public pure {
        value = 0;
    }

    function returnToSwapMenu() public {
        Terminal.print(0, "");
        tonswapEntryPoint(0);
    }

    function sendTokensViaMultisig(address sender, address destination, TvmCell payload) private pure {
        optional(uint256) pubkey = 0;
        IMultisig(sender).sendTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            callbackId: 0,
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(destination, Constants.SEND_WITH_MESSAGE, true, 1, payload);
    }

    function sendMessageViaKeys(address sender, address destination, uint8 tokenAmount, TvmCell payload) private pure {
        optional(uint256) pubkey = 0;
        ITIP3Token(sender).transfer{
            abiVer: 2,
            extMsg: true,
            sign: true,
            callbackId: 0,
            onErrorId: tvm.functionId(onError),
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(destination, tokenAmount, Constants.SEND_WITH_MESSAGE, addressZero, true, payload);
    }

    //========================================
    /// @notice TIP3 manage functionality goes here
    function tip3ManageEntryPoint(uint32 index) public {
        index = 0;

        MenuItem[] mi;
        mi.push(MenuItem("", "", tvm.functionId(addTIP3WalletEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(showTIP3WalletsEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(returnToMainMenu)));
        Menu.select("", "", mi);
    }

    function addTIP3WalletEntryPoint(uint32 index) public {
        index = 0;
        
        AddressInput.get(tvm.functionId(getTIP3Address), "");
    }
    
    function getTIP3Address(address value) public {
        tmpTIP3WalletAddress = value;
        Terminal.print(0, "");
        getTIP3WalletDetails(value, tvm.functionId(receiveTIP3WalletInfo));
    }

    function receiveTIP3WalletInfo(ITONTokenWalletDetails walletInfo) public {
        tmpWalletInfoStorage = walletInfo;
        Terminal.print(0, "Fetching information about your TIP-3 wallet's root contract");
        getTIP3RootDetails(walletInfo.root_address, tvm.functionId(receiveTIP3RootInfo));
    }

    function receiveTIP3RootInfo(IRootTokenContractDetails rootInfo) public {
        tmpRootInfoStorage = rootInfo;
        tmpDBRecord = transformToTIP3WalletInfo(tmpWalletInfoStorage, tmpRootInfoStorage, tmpTIP3WalletAddress);
        confirmWalletData();
    }

    function confirmWalletData() public {
        Terminal.print(0, buildWalletInfo(tmpDBRecord));
        ConfirmInput.get(tvm.functionId(confirmTIP3Details), "Is information correct?");
    }

    function confirmTIP3Details(bool value) public {
        if (value) {
            addTIP3(tmpDBRecord.root_address, tmpDBRecord);
            cleanUpTmpVars();
            Terminal.print(tvm.functionId(returnToTIP3ManageEntryPoint), "Great!");
        } else {
            ConfirmInput.get(tvm.functionId(nonCorrectInformationInput), "Try again?");
        }
    }

    function nonCorrectInformationInput(bool value) public {
        if (value) {
            addTIP3WalletEntryPoint(0);
        } else {
            returnToTIP3ManageEntryPoint();
        }
    }

    function showTIP3WalletsEntryPoint(uint32 index) public {
        index = 0;
        showTIP3Wallets();
    }

    function showTIP3Wallets() public {
        for ((, TIP3WalletInfo walletInfo) : tip3Wallets) {
            Terminal.print(0, buildWalletInfo(walletInfo));
        }

        returnToTIP3ManageEntryPoint();
    }

    function returnToTIP3ManageEntryPoint() public {
        Terminal.print(0, "Returning to TIP3 manage menu");
        tip3ManageEntryPoint(0);
    }

    function getTIP3WalletDetails(address wallet, uint32 callbackFunctionId) public pure {
        optional(uint256) pubkey;
        ITIP3Token(wallet).getDetails{
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

    function getTIP3RootDetails(address root, uint32 callbackFunctionId) public pure {
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

    function buildWalletInfo(TIP3WalletInfo walletInfo) private pure returns(string) {
        string tmpString;
        tmpString.append(format("{} token wallet\n", walletInfo.symbol));
        tmpString.append(format("Token balance: {}\n", walletInfo.balance));
        tmpString.append(format("Wallet address: {}\n", walletInfo.wallet_address));
        if (walletInfo.manageType == ManageType.MANAGE_WITH_KEYPAIR) {
            tmpString.append(format("Managed with pubkey {}\n", walletInfo.wallet_public_key));
        } else {
            tmpString.append(format("Managed with multisig {}\n", walletInfo.owner_address));
        }
        return tmpString;
    }

    function cleanUpTmpVars() private {
        delete tmpTIP3WalletAddress;
        delete tmpWalletInfoStorage;
        delete tmpRootInfoStorage;
        delete tmpDBRecord;
    }

    //========================================
    /// @notice Extra information functionality goes here
    function extraInfoEntryPoint(uint32 index) public {
        index = 0;

        printExtraInfoAndReturn();
    }

    function printExtraInfoAndReturn() public {
        Terminal.print(0, "SVOI.dev are the best");
        returnToMainMenu(0);
    }

    function returnToMainMenu(uint32 index) public {
        index = 0;
        mainMenu(0);
    }

    //========================================
    /// @notice Explorer functionality goes here
    function explorerEntryPoint(uint32 index) public {
        index = 0;
        explorerFunction();
    }

    function chooseSwapPair(uint32 functionId) public {
        MenuItem[] mi;
        delete swapPairsNumberToAddress;
        uint32 i = 0;
        for ((address swapPairAddress, SwapPairInfo spi) : swapPairs) {
            mi.push(MenuItem(spi.swapPairLPTokenName, "", functionId));
            swapPairsNumberToAddress[i] = spi.swapPairAddress;
        }

        mi.push(MenuItem("Return to main menu", "", tvm.functionId(returnToMainMenu)));
        Menu.select("Choose swap pair: ", "", mi);
    }

    function explorerFunction() public {
        //Terminal.print(0, "Explorer goes here.");
        returnToMainMenu(0);
    }

    //========================================
    /// @notice Error functionality goes here
    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("SdkError: {}, exitCode: {}", sdkError, exitCode));
        mainMenu(0);
    }
}