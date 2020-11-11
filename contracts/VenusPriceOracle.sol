pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./PriceOracle.sol";
import "./VBep20.sol";
import "./BEP20Interface.sol";
import "./SafeMath.sol";

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string calldata _base, string calldata _quote) external view returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] calldata _bases, string[] calldata _quotes) external view returns (ReferenceData[] memory);
}

contract VenusPriceOracle is PriceOracle {
    using SafeMath for uint256;

    mapping(address => uint) prices;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    IStdReference ref;

    constructor(IStdReference _ref) public {
        ref = _ref;
    }

    function getUnderlyingPrice(VToken vToken) public view returns (uint) {
        if (compareStrings(vToken.symbol(), "vBNB")) {
            IStdReference.ReferenceData memory data = ref.getReferenceData("BNB", "USD");
            return data.rate;
        }else if (compareStrings(vToken.symbol(), "XVS")) {
            return prices[address(vToken)];
        } else {
            BEP20Interface token = BEP20Interface(VBep20(address(vToken)).underlying());

            if(address(token) == address(0)) {
                return prices[address(vToken)];
            }

            IStdReference.ReferenceData memory data = ref.getReferenceData(token.symbol(), "USD");
            uint256 price = data.rate;

            uint decimalDelta = 18-uint(token.decimals());
            return price.mul(10**decimalDelta);
        }
    }

    function setUnderlyingPrice(VToken vToken, uint underlyingPriceMantissa) public {
        address asset = address(VBep20(address(vToken)).underlying());
        emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
        prices[asset] = underlyingPriceMantissa;
    }

    function setDirectPrice(address asset, uint price) public {
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}