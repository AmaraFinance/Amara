pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../Erc20Token/AErc20.sol";
import "../Erc20Token/AToken.sol";
import "../Oracle/PriceOracle.sol";
import "../EIP20/EIP20Interface.sol";
import "../Erc20Token/Mara.sol";
import "../Oracle/SimplePriceOracle.sol";

interface ComptrollerLensInterface {

    function compSpeeds(address) external view returns (uint);
    function compSupplyState(address) external view returns(uint224, uint32);
    function compBorrowState(address) external view returns(uint224, uint32);
    function compSupplierIndex(address, address) external view returns (uint);
    function compBorrowerIndex(address, address) external view returns (uint);

    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (AToken[] memory);
    function claimComp(address) external;
    function compAccrued(address) external view returns (uint);
    function getCompAddress() external view returns (address);
}

contract MaraLensMARA is ExponentialNoError {
    struct ATokenMARAData {
        address aToken;
        uint supplyMARAAPY;
        uint borrowMARAAPY;
    }

    function aTokenMARAMetadata(AToken aToken) view public returns (ATokenMARAData memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(aToken.comptroller()));
        uint speed = comptroller.compSpeeds(address(aToken));
        SimplePriceOracle priceOracle = SimplePriceOracle(address(comptroller.oracle()));
        uint maraPrice = priceOracle.assetPrices(comptroller.getCompAddress());
        // 24位小数
        uint exchangeRateCurrent = aToken.exchangeRateStored();
        uint totalPrice = aToken.totalSupply() * exchangeRateCurrent * priceOracle.getUnderlyingPrice(aToken);
        uint supplyAPY = 1000000000000000000 * 1000000 * 10512000 * speed * maraPrice / totalPrice;
        uint totalBorrowPrice = aToken.totalBorrows() * priceOracle.getUnderlyingPrice(aToken);
        uint borrowMARAAPY = 1000000 * 10512000 * speed * maraPrice / totalBorrowPrice;

        return ATokenMARAData({
            aToken: address(aToken),
            supplyMARAAPY: supplyAPY,
            borrowMARAAPY: borrowMARAAPY
            });
    }

    function calcMARAAPYs(AToken[] memory aTokens) public view returns (ATokenMARAData[] memory)  {
        uint aTokenCount = aTokens.length;
        ATokenMARAData[] memory res = new ATokenMARAData[](aTokenCount);

        for (uint i = 0; i < aTokenCount; i++) {
            AToken aToken = aTokens[i];
            res[i] = aTokenMARAMetadata(aToken);
        }
        return res;
    }
}
