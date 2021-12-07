pragma solidity ^0.5.16;

import "./PriceOracle.sol";
import "./AErc20.sol";
import "./SafeMath.sol";

contract GetPriceInterface {

    function latestAnswer() public view returns (uint256);

}

contract ConsumerV3Interface {
    /**
     * Returns the latest price
     */
    function getLatestPrice() external view returns (uint256);

    /**
     * Returns the decimals to offset on the getLatestPrice call
     */
    function decimals() external view returns (uint8);

    /**
     * Returns the description of the underlying price feed aggregator
     */
    function description() external view returns (string memory);
}

contract SimplePriceOracle is PriceOracle {
    using SafeMath for uint256;

    address admin;

    mapping(address => address) aTokenAssets;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    constructor() public {
        admin = msg.sender;
    }
    
    function getUnderlyingPrice(AToken aToken) public view returns (uint) {
        uint price;
        if (aTokenAssets[address(aToken)] != address(0)) {
            address priceAddress = aTokenAssets[address(aToken)];
            ConsumerV3Interface priceContract = ConsumerV3Interface(priceAddress);
            price = priceContract.getLatestPrice();
            uint latestPrice = price.mul(1000000).div(100000000);
            return latestPrice;
        }
    }

    function changeAdmin(address newAdmin) public {
        require(msg.sender == admin, "only the admin may call changeAdmin");
        admin = newAdmin;
    }

    function addATokenAddress(AToken aToken, address priceAddress) public {
        require(msg.sender == admin, "only the admin may call add");
        aTokenAssets[address(aToken)] = priceAddress;
    }

    function deleteATokenAddress(AToken aToken) public {
        require(msg.sender == admin, "only the admin may call delete");
        aTokenAssets[address(aToken)] = address(0);
    }

    function getATokenAddress(AToken aToken) public view returns (address){
        return aTokenAssets[address(aToken)];
    }

}
