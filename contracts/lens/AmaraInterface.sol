pragma solidity ^0.5.16;

import "../Governance/IERC20.sol";

contract AmaraInterface is IERC20 {
    function getCurrentVotes(address account) external view returns (uint256);

    function delegates(address delegatee) public view returns (address);

    function getPriorVotes(address account, uint256 blockNumber) public view returns (uint256);
}
