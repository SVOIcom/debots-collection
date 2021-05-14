pragma ton-solidity ^0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../../deinterfaces/AddressInput/AddressInput.sol";
import "../../deinterfaces/AmountInput/AmountInput.sol";
import "../../deinterfaces/ConfirmInput/ConfirmInput.sol";
import "../../deinterfaces/Menu/Menu.sol";
import "../../deinterfaces/Terminal/Terminal.sol";
import "../../deinterfaces/NumberInput/NumberInput.sol";
import "../../tonswapSC/contracts/SwapPair/helpers/TIP3TokenDeployer.sol";
import "../../tonswapSC/ton-eth-bridge-token-contracts/free-ton/contracts/interfaces/IRootTokenContract.sol";

abstract contract Debot {

    function getRequiredInterfaces() virtual public returns (uint256[] interfaces); 

    function getDebotInfo() virtual public view functionID(0xDEB) returns (
        string name, string version, string publisher, string caption, string author, 
        address support, string hello, string language, string dabi, bytes icon
    );
}

contract DebotA is Debot {
    uint owner;
    address tip3Deployer = address.makeAddrStd(0, 0xcd326f453ae7d6e857319efd3f655ff17aa98dab5558124088009f6c9f8bbb42);
    uint8 constant MULTISIG_WALLET = 0;
    uint8 constant SURF_WALLET = 1;

    uint8 m_options = 1;
    optional(string) m_debotAbi;
    optional(address) m_target;

    uint userPubkey;
    uint walletType;
    address userWalletAddress;
    bytes tip3name;
    bytes tip3symbol;
    uint8 decimals;
    uint128 deployGrams;

    address tip3RootAddress;

    constructor(string dabi) public {
        tvm.accept();
        m_debotAbi = dabi;
        owner = msg.pubkey();
    }

    function setTIP3DeployerAddress(address newTip3Deployer) external {
        require(msg.pubkey() == owner, 100);
        tvm.accept();
        tip3Deployer = newTip3Deployer;
    }

    function getRequiredInterfaces() override public returns (uint256[] interfaces) {
        return [AddressInput.ID, AmountInput.ID, ConfirmInput.ID, Menu.ID, Terminal.ID, NumberInput.ID];
    }

    function getDebotOptions() public view returns (uint8 options, string debotAbi, string targetAbi, address targetAddr) {
        debotAbi = m_debotAbi.hasValue() ? m_debotAbi.get() : "";
        targetAbi = m_debotAbi.hasValue() ? m_debotAbi.get() : "";
        targetAddr = m_target.hasValue() ? m_target.get() : address(0);
        options = m_options;
    }

    function getDebotInfo() override public view functionID(0xDEB) returns (
        string name, string version, string publisher, string caption, string author, 
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "SVOI-TIP3";
        version = "0.1.0";
        publisher = "SVOIdev";
        caption = "Create your TIP3";
        author = "Paul Mikhaylov";
        support = address.makeAddrStd(0, 0xce6769edeb0300d6478fb01a49eb5794396a007bab6d35be8bb9769efaf77639);
        hello = "Test";
        language = "en";
        dabi = m_debotAbi.get();
        icon = "data:image/png;base64,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";
    }

    fallback() external {
        Terminal.print(0, "Ooops, something's wrong. Returning to main menu.");
        actionMenu();
    }

    function start() public {
        controlMethodMenu();
    }

    function controlMethodMenu() public {
        Menu.select("Choose TIP-3 control method", "", [
            MenuItem("via your public key", "", tvm.functionId(getPublicKey)),
            MenuItem("via your multisig address", "", tvm.functionId(getMultisigWalletAddress)),
            MenuItem("via your surf wallet (not yet supported)", "", tvm.functionId(getSurfWalletAddress))
        ]);
    }

    function getPublicKey(uint32 index) public {
        Terminal.input(tvm.functionId(setPublicKey), "Enter your public key:", false);
    }

    function setPublicKey(string value) public {
        (uint tmpUserPubkey, bool res) = stoi(value);
        if (res) {
            userPubkey = tmpUserPubkey;
            userWalletAddress = address.makeAddrStd(0, 0);
            Terminal.print(tvm.functionId(actionMenu), "TIP-3 control method saved. Going to main menu.");
        } else {
            Terminal.print(tvm.functionId(redirectToGetPublicKey), "Invalid pubkey.");
        }
    }

    function redirectToGetPublicKey() public {
        getPublicKey(0);
    }

    function getMultisigWalletAddress(uint32 index) public {
        walletType = MULTISIG_WALLET;
        AddressInput.get(tvm.functionId(setUserWalletAddress), "Enter your multisig wallet address:");
    }

    function getSurfWalletAddress(uint32 index) public {
        Terminal.print(tvm.functionId(controlMethodMenu), "Surf wallets are not supported yet.");
    }

    function setUserWalletAddress(address value) public {
        userWalletAddress = value;
        userPubkey = uint256(0);
        Terminal.print(tvm.functionId(actionMenu), "TIP-3 control method saved. Going to main menu.");
    }

    function actionMenu() public {
        Menu.select("Choose action:", "", [
            MenuItem("Create TIP-3 token", "", tvm.functionId(initializeTIP3Deploy)),
            MenuItem("Deploy TIP-3 wallet with initial token balance", "", tvm.functionId(initializeTIP3WalletDeploy)),
            MenuItem("Change TIP-3 control method", "", tvm.functionId(redirectToControlMethodMenu)),
            MenuItem("About SVOIdev", "", tvm.functionId(infoAboutSvoiDev))
        ]);
    }

    function initializeTIP3Deploy(uint32 index) public {
        Terminal.print(tvm.functionId(getTIP3Name), "Now you will need to input some information about your TIP-3 token.");
    }

    function getTIP3Name() public {
        Terminal.input(tvm.functionId(setTIP3Name), "Enter name for your TIP-3 token:", false);
    }
    
    function setTIP3Name(string value) public {
        tip3name = bytes(value);
        getTIP3Symbol();
    }

    function getTIP3Symbol() public {
        Terminal.input(tvm.functionId(setTIP3Symbol), "Enter symbol (short name) for your TIP-3 token:", false);
    }

    function setTIP3Symbol(string value) public {
        tip3symbol = bytes(value);
        getDecimals();
    }

    function getDecimals() public {
        NumberInput.get(tvm.functionId(setDecimals), "Enter token decimals (recommended: 9):", 0, 255);
    }

    function setDecimals(uint256 value) public {
        decimals = uint8(value);
        getDeployGrams();
    }

    function getDeployGrams() public {
        AmountInput.get(tvm.functionId(setDeployGrams), "Enter amount of TON to use for TIP-3 deploy:", 9, 1e9, 10e9);
    }

    function setDeployGrams(uint128 value) public {
        deployGrams = value;
        showTIP3Info();
    }

    function showTIP3Info() public {
        Terminal.print(0, "Check if information is correct: ");
        Terminal.print(0, format("Name of TIP-3 token: {}", tip3name));
        Terminal.print(0, format("Symbol of TIP-3 token: {}", tip3symbol));
        Terminal.print(0, format("Decimals of TIP-3 token: {}", decimals));
        Terminal.print(0, format("TONs to use for deploy: {}.{}", deployGrams/(1 ton), deployGrams % (1 ton)));
        ConfirmInput.get(tvm.functionId(confirmTIP3Details), "Is information correct?");
    }

    function confirmTIP3Details(bool value) public {
        if (!value) {
            Terminal.print(tvm.functionId(getTIP3Name), "Please reenter TIP-3 information.");
        } else {
            deployTIP3RootContract();
        }
    }

    function deployTIP3RootContract() view public {
        optional(uint256) none;
        TIP3TokenDeployer(tip3Deployer).getFutureTIP3Address{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(testAddress),
            onErrorId: 0
        }(
            tip3name, tip3symbol, decimals, userPubkey
        );
    }

    function testAddress(address value0) public {
        Terminal.print(0, format("Future address: {}", value0));
        Terminal.print(0, "Returning to main menu");
        actionMenu();
    }

    function getRootTIP3Address(address tip3Address) public {
        Terminal.print(0, format("Future tip3 address: {}", tip3Address));
        Terminal.print(tvm.functionId(actionMenu), "Returning to main menu");
    }
    
    function initializeTIP3WalletDeploy(uint32 index) public {
        actionMenu();
    }

    function redirectToControlMethodMenu(uint32 index) public {
        controlMethodMenu();
    }

    function infoAboutSvoiDev(uint32 index) public {

    }
}