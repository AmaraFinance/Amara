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
    mapping(address => uint) prices;
    uint baseTokenPrice;
    string public baseSymbol;

    address admin;

    mapping(address => address) aTokenAssets;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    constructor(string memory symbol) public {
        admin = msg.sender;
        baseSymbol = symbol;
    }

    //function getUnderlyingPrice(AToken aToken) public view returns (uint) {
    //    if (compareStrings(aToken.symbol(), baseSymbol)) {
    //        return baseTokenPrice;
    //    } else {
    //        return prices[address(AErc20(address(aToken)).underlying())];
    //    }
    //}

    // binance

    //    function getUnderlyingPrice(AToken aToken) public view returns (uint) {
    //        uint price;
    //        if(aTokenAssets[address(aToken)] != address(0)){
    //            address priceAddress = aTokenAssets[address(aToken)];
    //            GetPriceInterface priceContract = GetPriceInterface(priceAddress);
    //            price = priceContract.latestAnswer();
    //            uint latestPrice = price.mul(1000000).div(100000000);
    //            return latestPrice;
    //        }else{
    //            if (compareStrings(aToken.symbol(), baseSymbol)) {
    //                return baseTokenPrice;
    //            } else {
    //                return prices[address(AErc20(address(aToken)).underlying())];
    //            }
    //        }
    //    }

    // moonbeam

    function getUnderlyingPrice(AToken aToken) public view returns (uint) {
        uint price;
        if (aTokenAssets[address(aToken)] != address(0)) {
            address priceAddress = aTokenAssets[address(aToken)];
            ConsumerV3Interface priceContract = ConsumerV3Interface(priceAddress);
            price = priceContract.getLatestPrice();
            uint latestPrice = price.mul(1000000).div(100000000);
            return latestPrice;
        } else {
            if (compareStrings(aToken.symbol(), baseSymbol)) {
                return baseTokenPrice;
            } else {
                return prices[address(AErc20(address(aToken)).underlying())];
            }
        }
    }

    function setUnderlyingPrice(AToken aToken, uint underlyingPriceMantissa) public {
        require(msg.sender == admin, "only the admin may call setUnderlyingPrice");
        if (compareStrings(aToken.symbol(), baseSymbol)) {
            baseTokenPrice = underlyingPriceMantissa;
        } else {
            address asset = address(AErc20(address(aToken)).underlying());
            emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
            prices[asset] = underlyingPriceMantissa;
        }
    }

    function setDirectPrice(address asset, uint price) public {
        require(msg.sender == admin, "only the admin may call setDirectPrice");
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function changeAdmin(address newAdmin) public {
        require(msg.sender == admin, "only the admin may call changeAdmin");
        admin = newAdmin;
    }

    // v1 price oracle interface for use as backing of proxy

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function setSymbol(string memory symbol) public {
        require(msg.sender == admin, "only the admin may call changeAdmin");
        baseSymbol = symbol;
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

