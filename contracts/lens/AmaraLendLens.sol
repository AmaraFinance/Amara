pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../AErc20.sol";
import "../AToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "./AmaraInterface.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);

    function oracle() external view returns (PriceOracle);

    function getAccountLiquidity(address) external view returns (uint, uint, uint);

    function getAssetsIn(address) external view returns (AToken[] memory);

    function claimComp(address) external;

    function compAccrued(address) external view returns (uint);
}

contract AmaraLendLens {
    struct ATokenMetadata {
        address aToken;
        uint exchangeRateStored;
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
        uint underlyingPrice;
    }

    function aTokenMetadata(AToken aToken) public view returns (ATokenMetadata memory) {
        uint exchangeRateStored = aToken.exchangeRateStored();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(aToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(aToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(aToken.symbol(), "AMOVR")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            AErc20 aErc20 = AErc20(address(aToken));
            underlyingAssetAddress = aErc20.underlying();
            underlyingDecimals = EIP20Interface(aErc20.underlying()).decimals();
        }

        return ATokenMetadata({
        aToken : address(aToken),
        exchangeRateStored : exchangeRateStored,
        supplyRatePerBlock : aToken.supplyRatePerBlock(),
        borrowRatePerBlock : aToken.borrowRatePerBlock(),
        reserveFactorMantissa : aToken.reserveFactorMantissa(),
        totalBorrows : aToken.totalBorrows(),
        totalReserves : aToken.totalReserves(),
        totalSupply : aToken.totalSupply(),
        totalCash : aToken.getCash(),
        isListed : isListed,
        collateralFactorMantissa : collateralFactorMantissa,
        underlyingAssetAddress : underlyingAssetAddress,
        aTokenDecimals : aToken.decimals(),
        underlyingDecimals : underlyingDecimals,
        underlyingPrice : priceOracle.getUnderlyingPrice(aToken)
        });
    }

    function aTokenMetadataAll(AToken[] memory aTokens) public view returns (ATokenMetadata[] memory) {
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
        uint tokenBalance;
        uint tokenAllowance;
    }

    function aTokenBalances(AToken aToken, address payable account) public view returns (ATokenBalances memory) {
        uint balanceOf = aToken.balanceOf(account);
        uint borrowBalanceCurrent = aToken.borrowBalanceStored(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(aToken.symbol(), "AMOVR")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            AErc20 aErc20 = AErc20(address(aToken));
            EIP20Interface underlying = EIP20Interface(aErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(aToken));
        }

        return ATokenBalances({
        aToken : address(aToken),
        balanceOf : balanceOf,
        borrowBalanceCurrent : borrowBalanceCurrent,
        tokenBalance : tokenBalance,
        tokenAllowance : tokenAllowance
        });
    }

    function aTokenBalancesAll(AToken[] memory aTokens, address payable account) public view returns (ATokenBalances[] memory) {
        uint aTokenCount = aTokens.length;
        ATokenBalances[] memory res = new ATokenBalances[](aTokenCount);
        for (uint i = 0; i < aTokenCount; i++) {
            res[i] = aTokenBalances(aTokens[i], account);
        }
        return res;
    }

    struct AccountLimits {
        AToken[] markets;
        uint liquidity;
        uint shortfall;
    }

    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public view returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
        markets : comptroller.getAssetsIn(account),
        liquidity : liquidity,
        shortfall : shortfall
        });
    }

    struct CompBalanceMetadata {
        uint balance;
        uint votes;
        address delegate;
    }

    function getCompBalanceMetadata(AmaraInterface amara, address account) external view returns (CompBalanceMetadata memory) {
        return CompBalanceMetadata({
        balance : amara.balanceOf(account),
        votes : uint256(amara.getCurrentVotes(account)),
        delegate : amara.delegates(account)
        });
    }

    struct CompBalanceMetadataExt {
        uint balance;
        uint votes;
        address delegate;
        uint allocated;
    }

    function getCompBalanceMetadataExt(AmaraInterface amara, ComptrollerLensInterface comptroller, address account) external returns (CompBalanceMetadataExt memory) {
        uint balance = amara.balanceOf(account);
        comptroller.claimComp(account);
        uint newBalance = amara.balanceOf(account);
        uint accrued = comptroller.compAccrued(account);
        uint total = add(accrued, newBalance, "sum AMARA total");
        uint allocated = sub(total, balance, "sub allocated");

        return CompBalanceMetadataExt({
        balance : balance,
        votes : uint256(amara.getCurrentVotes(account)),
        delegate : amara.delegates(account),
        allocated : allocated
        });
    }

    struct CompVotes {
        uint blockNumber;
        uint votes;
    }

    function getCompVotes(AmaraInterface amara, address account, uint32[] calldata blockNumbers) external view returns (CompVotes[] memory) {
        CompVotes[] memory res = new CompVotes[](blockNumbers.length);
        for (uint i = 0; i < blockNumbers.length; i++) {
            res[i] = CompVotes({
            blockNumber : uint256(blockNumbers[i]),
            votes : uint256(amara.getPriorVotes(account, blockNumbers[i]))
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
