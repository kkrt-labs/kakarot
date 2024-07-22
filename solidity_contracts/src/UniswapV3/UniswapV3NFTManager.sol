pragma solidity >=0.7.0;
pragma abicoder v2;

import "openzeppelin/token/ERC721/ERC721.sol";
import "./NFTDescriptor.sol";

contract UniswapV3NFTManager is ERC721 {
    constructor() ERC721("UniswapV3 NFT Positions", "UNIV3") {}

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _mockTokenUri(tokenId);
    }

    function tokenURIExternal(uint256 tokenId) external returns (string memory) {
        return _mockTokenUri(tokenId);
    }

    function _mockTokenUri(uint256 tokenId) internal view returns (string memory) {
        NFTDescriptor.ConstructTokenURIParams memory params = NFTDescriptor.ConstructTokenURIParams({
            tokenId: tokenId,
            quoteTokenAddress: address(0xabcdef),
            baseTokenAddress: address(0x123456),
            quoteTokenSymbol: "ETH",
            baseTokenSymbol: "USDC",
            quoteTokenDecimals: 18,
            baseTokenDecimals: 6,
            flipRatio: false,
            tickLower: -887272,
            tickUpper: 887272,
            tickCurrent: 387272,
            tickSpacing: 1000,
            fee: 3000,
            poolAddress: address(0xc0de)
        });

        return NFTDescriptor.constructTokenURI(params);
    }
}
