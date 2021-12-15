pragma solidity ^0.5.8;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface AErc20Delegator {
    function underlying() external view returns (address);
    function mint(uint mintAmount) external returns (uint);
}

interface AETHDelegator {
    function underlying() external view returns (address);
    function mint() external payable;
}

contract LendMintProvider {
    address private _owner;

    constructor() public {
        _owner = msg.sender;
    }

    function mint(address cToken, uint256 mintAmount) public payable returns (bool) {
        require(msg.sender == _owner, "sender is not owner");
        AErc20Delegator delegator = AErc20Delegator(cToken);
        IERC20 token = IERC20(delegator.underlying());
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance >= mintAmount, "token is not sufficient");
        token.approve(cToken, mintAmount);
        delegator.mint(mintAmount);
        return true;
    }

    function mintETH(address cToken, uint256 mintAmount) public payable returns (bool) {
        require(msg.sender == _owner, "sender is not owner");
        AETHDelegator delegator = AETHDelegator(cToken);
        uint256 ethBalance = address(this).balance;
        require(ethBalance >= mintAmount, "eth is not sufficient");
        delegator.mint.value(mintAmount)();
        return true;
    }


/**
     * @notice Receive Ether
     */
    function () external payable{
        
    }


}