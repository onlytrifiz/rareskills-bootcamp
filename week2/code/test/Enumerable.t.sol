// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {NFT, PrimeChecker} from "src/Enumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract EnumerableTest is Test, IERC721Receiver {
    NFT public nft;
    PrimeChecker public primeChecker;

    function setUp() public {
        nft = new NFT();
        primeChecker = new PrimeChecker(nft);
    }

    function testSafeMint() public {
        for (uint256 i = 1; i <= 100; i++) {
            nft.safeMint(address(this), i);
        }
    }

    function testPrimeChecker() public returns (uint8) {
        testSafeMint();

        uint8 primeNumbers = primeChecker.primeCheck(address(this));
        console2.log(primeNumbers);
        return primeNumbers;
    }

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
