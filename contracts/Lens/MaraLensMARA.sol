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
    uint224 public constant compInitialIndex = 1e36;

    struct CompMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

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
        uint supplyAPY = 1000000000000000000 * 1000000 * 5256000 * speed * maraPrice / totalPrice;
        uint totalBorrowPrice = aToken.totalBorrows() * priceOracle.getUnderlyingPrice(aToken);
        uint borrowMARAAPY = 1000000 * 5256000 * speed * maraPrice / totalBorrowPrice;

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

    
    function getAccountBorrowAccrued(address account, AToken aToken) internal view returns (uint){
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(aToken.comptroller()));
        ATokenInterface aTokenInterface = ATokenInterface(address(aToken));
        uint compBorrowerIndex = 0;
        uint224 borrowStateIndex;

        Exp memory marketBorrowIndex = Exp({mantissa : aToken.borrowIndex()});
        if (compBorrowerIndex == 0) {
            compBorrowerIndex = comptroller.compBorrowerIndex(address(aToken), account);
        }
        (borrowStateIndex,) = comptroller.compBorrowState(address(aToken));
        Double memory borrowIndex = Double({mantissa : borrowStateIndex});
        Double memory borrowerIndex = Double({mantissa : compBorrowerIndex});
        compBorrowerIndex = borrowIndex.mantissa;

        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(aTokenInterface.borrowBalanceStored(account), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
            return borrowerDelta;
        }
        return 0;
    }

    function getAccountSupplyAccrued(address account, AToken aToken) internal view returns (uint){
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(aToken.comptroller()));
        ATokenInterface aTokenInterface = ATokenInterface(address(aToken));
        uint compSupplierIndex = 0;
        uint224 supplyStateIndex;

        if (compSupplierIndex == 0) {
            compSupplierIndex = comptroller.compSupplierIndex(address(aToken), account);
        }
        (supplyStateIndex,) = comptroller.compSupplyState(address(aToken));
        Double memory supplyIndex = Double({mantissa : supplyStateIndex});
        Double memory supplierIndex = Double({mantissa : compSupplierIndex});
        compSupplierIndex = supplyIndex.mantissa;

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = compInitialIndex;
        }

        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = aTokenInterface.balanceOf(account);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);
        return supplierDelta;
    }

    function calAccountAccrued(address account, AToken aToken) public view returns (uint){
        uint sum = 0;
        sum = sum + getAccountBorrowAccrued(account, aToken);
        sum = sum + getAccountSupplyAccrued(account, aToken);
        return sum;
    }

    function calcAccountAllAccrued(address account, AToken[] memory aTokens) public view returns (uint){
        uint res = 0;
        for (uint i = 0; i < aTokens.length; i++) {
            AToken aToken = aTokens[i];
            res = res + calAccountAccrued(account, aToken);
        }
        return res;
    }
}
