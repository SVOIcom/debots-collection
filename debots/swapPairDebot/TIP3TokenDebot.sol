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

// Function ids: A**

contract TonSwapTIP3Debot is Debot, TIP3WalletsDatabase, StringContract, Upgradable {
    enum CURRENT_OPERATION { SWAP, PROVIDE_LP, PROVIDE_LP_ONE, WITHDRAW_LP, WITHDRAW_LP_ONE }
    address constant addressZero = address.makeAddrStd(0, 0);
    uint128 constant maxUint128 = 340282366920938463463374607431768211455;

    CURRENT_OPERATION currentOperation;
    address tmpTIP3WalletAddress;
    ITONTokenWalletDetails tmpWalletInfoStorage;
    IRootTokenContractDetails tmpRootInfoStorage;
    TIP3WalletInfo tmpDBRecord;
    address swapPairAddress;
    uint32 tokenIndex;
    uint8 rootCounter;
    uint128 amount1; uint128 amount2;
    optional(uint256) pubkey_;
    ManageType tmpManageType;
    TvmCell payload;

    bytes symbol1; bytes symbol2;

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
        cleanUpTmpVars();
        mainMenu(0);
    }

    function mainMenu(uint32 index) public {
        index = 0;

        MenuItem[] mi;
        mi.push(MenuItem(vals[10], vals[11], 0xA0));
        mi.push(MenuItem(vals[12], vals[13], 0xA1));
        mi.push(MenuItem(vals[14], vals[15], 0xA2));
        Menu.select(vals[18], vals[19], mi);
    }

    //========================================
    /// @notice TonSwap functionality goes here
    function tonswapEntryPoint(uint32 index) functionID(0xA0) public {
        // chooseSwapPair(0xB0);
        // chooseSwapPairAction(0);
        AddressInput.get(0xB0, vals[20]);
    }

    function getSwapPairAddress(address value) functionID(0xB0) public {
        swapPairAddress = value;
        optional(uint256) pubkey;
        SwapPair(swapPairAddress).getPairInfo{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: 0xB1,
            onErrorId: 0,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(0);
    }

    function receiveSwapPairInfo(SwapPairInfo spi_) functionID(0xB1) public {
        spi = spi_;
        rootCounter = 0;
        getTIP3RootDetails(spi.tokenRoot1, 0xB2);
        getTIP3RootDetails(spi.tokenRoot1, 0xB3);
    }

    function receiveFirstTIP3Info(IRootTokenContractDetails rootInfo) functionID(0xB2) public {
        symbol1 = rootInfo.symbol;
        rootCounter++;
        if (rootCounter == 2)
            chooseSwapPairAction();
    }

    function receiveSecondTIP3Info(IRootTokenContractDetails rootInfo) functionID(0xB3) public {
        symbol2 = rootInfo.symbol;
        rootCounter++;
        if (rootCounter == 2)
            chooseSwapPairAction();
    }

    function chooseSwapPairAction()  public {
        Terminal.print(0, format("Swap pair: {}", spi.swapPairLPTokenName));
        MenuItem[] mi;

        mi.push(MenuItem(vals[20], vals[21], 0xC0));
        mi.push(MenuItem(vals[22], vals[23], 0xC0));
        mi.push(MenuItem(vals[24], vals[25], tvm.functionId(provideLiquidityOneTokenEntryPoint)));
        mi.push(MenuItem(vals[26], vals[27], tvm.functionId(withdrawLiquidityEntryPoint)));
        mi.push(MenuItem(vals[28], vals[29], tvm.functionId(withdrawLiquidityOneTokenEntryPoint)));
        mi.push(MenuItem(vals[30], vals[31], tvm.functionId(mainMenu)));

        Menu.select(vals[32], vals[33], mi);
    }

    function swapTokensEntyPoint(uint32 index) functionID(0xC0) public {
        MenuItem[] mi;
        mi.push(MenuItem(
            symbol1,
            "", 
            0xC1)
        );
        mi.push(MenuItem(
            symbol2,
            "", 
            0xC1)
        );
        Menu.select(vals[36], "", mi);
    }

    function getWalletForSwap(uint32 index) functionID(0xC1) public {
        tokenIndex = index;
        AmountInput.get(
            0xC2, 
            vals[37], 
            0,
            0, 
            maxUint128
        );
    }

    function getAmountForSwap(uint128 value) functionID(0xC2) public {
        amount1 = value;
        SwapPair(spi.swapPairAddress).createSwapPayload{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: 0xC3,
            onErrorId: 0,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey_
        }(tip3Wallets[tokenIndex == 1? spi.tokenRoot1:spi.tokenRoot2].wallet_address);
    }

    function getSwapPayload(TvmCell receivedPayload) functionID(0xC3) public {
        payload = receivedPayload;
        performSwapOperation();
    }

    function performSwapOperation() public {
        if (tip3Wallets[tokenIndex == 1? spi.tokenRoot1:spi.tokenRoot2].manageType == ManageType.MANAGE_WITH_KEYPAIR) {
            sendMessageViaKeys(
                tip3Wallets[tokenIndex == 1? spi.tokenRoot1:spi.tokenRoot2].wallet_address,
                tokenIndex == 1? spi.tokenWallet1 : spi.tokenWallet2,
                amount1,
                payload
            );
        } else {

        }
        Terminal.print(0xE2, vals[38]);
    }

    function provideLiquidityEntryPoint(uint32 index) functionID(0xC0) public {
        Terminal.print(0, vals[40]);
        AmountInput.get(0xE0, vals[41], 9, 0, maxUint128);
        AmountInput.get(0xE1, vals[42], 9, 0, maxUint128);
        Terminal.print(0xC1, vals[43]);
    }

    function performLiquidityProvidingOperation() functionID(0xC1) public {
        Terminal.print(0xE2, vals[44]);
    }

    function provideLiquidityOneTokenEntryPoint(uint32 index) public {
        AmountInput.get(0xE0,  format("${}", index+1), 9, 0, maxUint128);
        Terminal.print(tvm.functionId(performLiquidityProvidingOneTokenOperation), " ");
    }

    function performLiquidityProvidingOneTokenOperation() public {
        Terminal.print(0xE2, " ");
    }

    function withdrawLiquidityEntryPoint(uint32 index) public {
        AmountInput.get(0xE0,  format("{}", index+1), 9, 0, 10);
        Terminal.print(tvm.functionId(performLiquidityWithdrawingOperation), " ");
    }

    function performLiquidityWithdrawingOperation() public {
        Terminal.print(0xE2, "");
    }

    function withdrawLiquidityOneTokenEntryPoint(uint32 index) public {
        AmountInput.get(0xE0,  format("{}", index+1), 9, 0, 10);
        MenuItem[] mi;
        mi.push(MenuItem(
            format("{}", index+1), 
            format("{}{}", index, index), 
            tvm.functionId(getWalletForLPWithdraw))
        );
        mi.push(MenuItem(
            format("{}", index+1), 
            format("{}{}", index, index), 
            tvm.functionId(getWalletForLPWithdraw))
        );
        Menu.select("", "", mi);
    }

    function getWalletForLPWithdraw(uint32 index) public {
        Terminal.print(0, format("{}", index));
        performLiquidityWithdrawingOneTokenOperation();
    }

    function performLiquidityWithdrawingOneTokenOperation() public {
        Terminal.print(0xE2, "");
    }

    function getFirstTokenAmount(uint128 value) functionID(0xE0) public pure {
    }

    function getSecondTokenAmount(uint128 value) functionID(0xE1) public pure {
    }

    function returnToSwapMenu() functionID(0xE2) public {
        Terminal.print(0, "a");
        tonswapEntryPoint(0);
    }

    function sendTokensViaMultisig(address sender, address destination, TvmCell payload_) private pure {
        optional(uint256) pubkey = 0;
        IMultisig(sender).sendTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            callbackId: 0,
            onErrorId: 0xEEE,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(destination, Constants.SEND_WITH_MESSAGE, true, 1, payload_);
    }

    function sendMessageViaKeys(address sender, address destination, uint128 tokenAmount, TvmCell payload_) private pure {
        optional(uint256) pubkey = 0;
        ITIP3Token(sender).transfer{
            abiVer: 2,
            extMsg: true,
            sign: true,
            callbackId: 0,
            onErrorId: 0xEEE,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }(destination, tokenAmount, Constants.SEND_WITH_MESSAGE, addressZero, true, payload_);
    }

    //========================================
    /// @notice TIP3 manage functionality goes here
    function tip3ManageEntryPoint(uint32 index) functionID(0xA1) public {
        index = 0;

        MenuItem[] mi;
        mi.push(MenuItem("", "", tvm.functionId(addTIP3WalletEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(showTIP3WalletsEntryPoint)));
        mi.push(MenuItem("", "", tvm.functionId(mainMenu)));
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
        Terminal.print(0, " contract");
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
        showTIP3Wallets();
    }

    function showTIP3Wallets() public {
        for ((, TIP3WalletInfo walletInfo) : tip3Wallets) {
            Terminal.print(0, buildWalletInfo(walletInfo));
        }

        returnToTIP3ManageEntryPoint();
    }

    function returnToTIP3ManageEntryPoint() public {
        Terminal.print(0, " menu");
        tip3ManageEntryPoint(0);
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
        tmpString.append(format("{} token wallet\n", walletInfo.symbol));
        tmpString.append(format("Balance: {}\n", walletInfo.balance));
        tmpString.append(format("Wallet Address: {}\n", walletInfo.wallet_address));
        if (walletInfo.manageType == ManageType.MANAGE_WITH_KEYPAIR) {
            tmpString.append(format("Pubkey: {}\n", walletInfo.wallet_public_key));
        } else {
            tmpString.append(format("Multisig: {}\n", walletInfo.owner_address));
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
    function extraInfoEntryPoint(uint32 index) functionID(0xA2) public {

        printExtraInfoAndReturn();
    }

    function printExtraInfoAndReturn() public {
        Terminal.print(0, "SVOI.dev are the best");
        mainMenu(0);
    }

    function returnToMainMenu() public {
        mainMenu(0);
    }

    //========================================
    /// @notice Error functionality goes here
    function onError(uint32 sdkError, uint32 exitCode) functionID(0xEEE) public {
        Terminal.print(0, format("SdkError: {}, exitCode: {}", sdkError, exitCode));
        mainMenu(0);
    }
}