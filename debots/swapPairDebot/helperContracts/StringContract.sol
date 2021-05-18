pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

contract StringContract {
    string[] vals;

    // 1 - 6 debot info
    // 10 - 19 main menu
    // 20 - 32 tonswap menu
    function setStringInfo(bytes[] input, uint8 offset, uint8 length) public {
        require(tvm.pubkey() == msg.pubkey());
        tvm.accept();
        for (uint8 i = 0; i < length; i++) {
            vals.push(input[i]);
        }
    }

    // // 1 - 9
    // function setDebotInfo(bytes[] input) public {
    //     require(tvm.pubkey() == msg.pubkey());
    //     tvm.accept();
    //     for (uint8 i = 0; i < 5; i++) {
    //         vals[i+1] = input[i];
    //     }
    // }

    // // 10 - 20
    // function setMainMenuInfo(bytes[] input) public {
    //     require(tvm.pubkey() == msg.pubkey());
    //     tvm.accept();
    //     for (uint8 i = 0; i < 10; i++)
    //         vals[i+10] = input[i];
    // }
}