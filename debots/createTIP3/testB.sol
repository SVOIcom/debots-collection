pragma ton-solidity >= 0.6.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

contract B {
    function test(bytes a, bytes b) public returns (bytes){
        return format("{}{}{}{}", a, b, a, b);
    }
}