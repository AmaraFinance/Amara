pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../Erc20Token/AErc20.sol";
import "../Erc20Token/AToken.sol";
import "../Oracle/PriceOracle.sol";
import "../EIP20/EIP20Interface.sol";
import "../Erc20Token/Mara.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (AToken[] memory);
    function claimComp(address) external;
    function compAccrued(address) external view returns (uint);
}

contract MaraLens {
    struct ATokenMetadata {
        address aToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint aTokenDecimals;
        uint underlyingDecimals;
    }

    function aTokenMetadata(AToken aToken) public returns (ATokenMetadata memory) {
        uint exchangeRateCurrent = aToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(aToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(aToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(aToken.symbol(), "maraT")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            AErc20 AErc20 = AErc20(address(aToken));
            underlyingAssetAddress = AErc20.underlying();
            underlyingDecimals = EIP20Interface(AErc20.underlying()).decimals();
        }

        return ATokenMetadata({
            aToken: address(aToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: aToken.supplyRatePerBlock(),
            borrowRatePerBlock: aToken.borrowRatePerBlock(),
            reserveFactorMantissa: aToken.reserveFactorMantissa(),
            totalBorrows: aToken.totalBorrows(),
            totalReserves: aToken.totalReserves(),
            totalSupply: aToken.totalSupply(),
            totalCash: aToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            aTokenDecimals: aToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }

    function aTokenMetadataAll(AToken[] calldata aTokens) external returns (ATokenMetadata[] memory) {
        uint aTokenCount = aTokens.length;
        ATokenMetadata[] memory res = new ATokenMetadata[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = aTokenMetadata(aTokens[i]);
        }
        return res;
    }

    struct ATokenBalances {
        address aToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function aTokenBalances(AToken aToken, address payable account) public returns (ATokenBalances memory) {
        uint balanceOf = aToken.balanceOf(account);
        uint borrowBalanceCurrent = aToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = aToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(aToken.symbol(), "maraT")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            AErc20 AErc20 = AErc20(address(aToken));
            EIP20Interface underlying = EIP20Interface(AErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(aToken));
        }

        return ATokenBalances({
            aToken: address(aToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function aTokenBalancesAll(AToken[] calldata aTokens, address payable account) external returns (ATokenBalances[] memory) {
        uint aTokenCount = aTokens.length;
        ATokenBalances[] memory res = new ATokenBalances[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = aTokenBalances(aTokens[i], account);
        }
        return res;
    }

    struct ATokenUnderlyingPrice {
        address aToken;
        uint underlyingPrice;
    }

    function aTokenUnderlyingPrice(AToken aToken) public returns (ATokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(aToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return ATokenUnderlyingPrice({
            aToken: address(aToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(aToken)
        });
    }

    function aTokenUnderlyingPriceAll(AToken[] calldata aTokens) external returns (ATokenUnderlyingPrice[] memory) {
        uint aTokenCount = aTokens.length;
        ATokenUnderlyingPrice[] memory res = new ATokenUnderlyingPrice[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = aTokenUnderlyingPrice(aTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        AToken[] markets;
        uint liquidity;
        uint shortfall;
    }

    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
            markets: comptroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct CompBalanceMetadata {
        uint balance;
        uint votes;
        address delegate;
    }

    function getCompBalanceMetadata(Mara mara, address account) external view returns (CompBalanceMetadata memory) {
        return CompBalanceMetadata({
            balance: mara.balanceOf(account),
            votes: uint256(mara.getCurrentVotes(account)),
            delegate: mara.delegates(account)
        });
    }

    struct CompBalanceMetadataExt {
        uint balance;
        uint votes;
        address delegate;
        uint allocated;
    }

    function getCompBalanceMetadataExt(Mara mara, ComptrollerLensInterface comptroller, address account) external returns (CompBalanceMetadataExt memory) {
        uint balance = mara.balanceOf(account);
        comptroller.claimComp(account);
        uint newBalance = mara.balanceOf(account);
        uint accrued = comptroller.compAccrued(account);
        uint total = add(accrued, newBalance, "sum MARA total");
        uint allocated = sub(total, balance, "sub allocated");

        return CompBalanceMetadataExt({
            balance: balance,
            votes: uint256(mara.getCurrentVotes(account)),
            delegate: mara.delegates(account),
            allocated: allocated
        });
    }

    struct CompVotes {
        uint blockNumber;
        uint votes;
    }

    function getCompVotes(Mara mara, address account, uint32[] calldata blockNumbers) external view returns (CompVotes[] memory) {
        CompVotes[] memory res = new CompVotes[](blockNumbers.length);
        for (uint i = 0; i < blockNumbers.length; i++) {
            res[i] = CompVotes({
                blockNumber: uint256(blockNumbers[i]),
                votes: uint256(mara.getPriorVotes(account, blockNumbers[i]))
            });
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }
}
