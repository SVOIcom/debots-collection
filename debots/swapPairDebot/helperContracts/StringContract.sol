pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

contract StringContract {
    mapping(uint8 => string) vals;

    function setStringInfo(bytes[] input, uint8 offset, uint8 length) public {
        require(tvm.pubkey() == msg.pubkey());
        tvm.accept();
        for (uint8 i = 0; i < length; i++) {
            vals[i+offset] = input[i];
        }
    }
}