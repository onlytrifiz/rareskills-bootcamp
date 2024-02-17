// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TokenGodMode} from "../src/TokenGodMode.sol";

contract TokenGodModeTest is Test {
    TokenGodMode public tokenGodMode;

    address public god = address(this);
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        tokenGodMode = new TokenGodMode();
    }

    function testTransfer() public {
        tokenGodMode.transfer(user1, 10 ether);
        tokenGodMode.transfer(user2, 10 ether);

        assertEq(tokenGodMode.balanceOf(god), 80 ether);
        assertEq(tokenGodMode.balanceOf(user1), 10 ether);
        assertEq(tokenGodMode.balanceOf(user2), 10 ether);
    }

    function testApprovedUserTransferFrom() public {
        testTransfer();

        vm.prank(user1);
        tokenGodMode.approve(user2, 5 ether);

        vm.prank(user2);
        tokenGodMode.transferFrom(user1, god, 5 ether);

        assertEq(tokenGodMode.balanceOf(god), 85 ether);
        assertEq(tokenGodMode.balanceOf(user1), 5 ether);
        assertEq(tokenGodMode.balanceOf(user2), 10 ether);
    }

    function testNotApprovedUserTransferFrom() public {
        testTransfer();

        vm.expectRevert();
        vm.prank(user2);
        tokenGodMode.transferFrom(user1, god, 5 ether);
    }

    function testNotApprovedGodTransferFrom() public {
        testTransfer();

        tokenGodMode.transferFrom(user1, god, 5 ether);
        assertEq(tokenGodMode.balanceOf(god), 85 ether);
        assertEq(tokenGodMode.balanceOf(user1), 5 ether);
        assertEq(tokenGodMode.balanceOf(user2), 10 ether);
    }
}
