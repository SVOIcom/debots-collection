pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../interfaces/TokenInterface.sol";
import "../interfaces/SwapPairInterface.sol";

contract SwapPairDatabase {

    // All swap pairs
    uint256[] swapPairsID;
    mapping (address => SwapPairInfo) swapPairs;
    mapping (uint32 => address) swapPairsNumberToAddress;
    address rootAddress;

    function setRootAddress(address rootSwapPairAddress) public {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        rootAddress = rootSwapPairAddress;
    }

    function requestSwapPairsList() public view {
        optional(uint256) pubkey;
        IRootSwapPair(rootAddress).getAllSwapPairsID{
            abiVer: 2,
            extMsg: true,
            sign: false,
            callbackId: tvm.functionId(getSwapPairList),
            onErrorId: 0,
            time: uint64(now),
            expire: 0,
            pubkey: pubkey
        }();
    }

    function getSwapPairList(uint256[] ids) public {
        swapPairsID = ids;
        getSwapPairsInfo();
    }

    function getSwapPairsInfo() public view {
        optional(uint256) pubkey;
        for (uint256 id: swapPairsID) {
            IRootSwapPair(rootAddress).getPairInfoByID{
                abiVer: 2,
                extMsg: true,
                sign: false,
                callbackId: tvm.functionId(addSwapPairToDB),
                onErrorId: 0,
                time: uint64(now),
                expire: 0,
                pubkey: pubkey
            }(id);
        }
    }

    function addSwapPairToDB(SwapPairInfo spi) public {
        if (swapPairs.exists(spi.swapPairAddress)) {
            swapPairs.replace(spi.swapPairAddress, spi);
        } else {
            swapPairs.add(spi.swapPairAddress, spi);
        }
    }
}