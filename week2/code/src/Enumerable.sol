// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT is ERC721, ERC721Enumerable {
    constructor() ERC721("NonFungibleToken", "NFT") {}

    function safeMint(address to, uint256 tokenId) public {
        require(tokenId > 0 && tokenId <= 100); // && totalSupply() <= 20);

        _safeMint(to, tokenId);
    }

    // The following functions are overrides required by Solidity.
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

contract PrimeChecker {
    NFT public nft;

    constructor(NFT _nft) {
        nft = _nft;
    }

    function primeCheck(address addr) public view returns (uint8) {
        uint8 primeNumbers;
        uint8 balanceOf = uint8(nft.balanceOf(addr));

        for (uint256 i; i < balanceOf; i++) {
            uint8 n = uint8(nft.tokenOfOwnerByIndex(addr, i));

            uint8 sqrtN = sqrt(n);
            bool isPrime = true;
            for (uint8 j = 2; j <= sqrtN; j++) {
                if (n % j == 0) {
                    isPrime = false;
                    break;
                }
            }
            if (isPrime) primeNumbers++;
        }
        return primeNumbers;
    }

    function sqrt(uint8 y) internal pure returns (uint8 z) {
        z = y;
        uint8 x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }
}
