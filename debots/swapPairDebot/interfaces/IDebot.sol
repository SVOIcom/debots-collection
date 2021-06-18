pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

//================================================================================
//
abstract contract Debot 
{
    uint8 constant   DEBOT_ABI = 1;
    uint8            m_options;
    optional(bytes)  m_icon;
    optional(string) m_debotAbi;

    /// @notice DeBot entry point.
    function start() public virtual;

    /// @notice DeBot version and title.
    function getVersion() public virtual returns (string name, uint24 semver);

    /// @notice Returns DeBot ABI.
    function getDebotOptions() public view returns (uint8 options, string debotAbi, string targetAbi, address targetAddr) 
    {
        debotAbi   = m_debotAbi.hasValue() ? m_debotAbi.get() : "";
        targetAbi  = "";
        targetAddr = address(0);
        options    = m_options;
    }

    /// @notice Allow to set debot ABI. Do it before using debot.
    function setABI(string dabi) public 
    {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        m_options |= DEBOT_ABI;
        m_debotAbi = dabi;
    }

    function setIcon(bytes icon) public 
    {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        m_icon = icon;
    }

    function getRequiredInterfaces() virtual public pure returns (uint256[] interfaces);

    function getDebotInfo() virtual public view functionID(0xDEB) returns (
        string name, string version, string publisher, string caption, string author, 
        address support, string hello, string language, string dabi, bytes icon
    );
}

//================================================================================
//
