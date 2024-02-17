// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TokenSanctions} from "../src/TokenSanctions.sol";

contract TokenSanctionsTest is Test {
    TokenSanctions public tokenSanctions;

    address public admin = address(this);
    address public user = address(1);
    address public restrictedUser = address(2);

    function setUp() public {
        tokenSanctions = new TokenSanctions();
    }

    function testAdminTransfer() public {
        tokenSanctions.transfer(user, 10 ether);
        assertEq(tokenSanctions.balanceOf(admin), 90 ether);
        assertEq(tokenSanctions.balanceOf(user), 10 ether);
    }

    function testUserTransfer() public {
        testAdminTransfer();

        vm.prank(user);
        tokenSanctions.transfer(admin, 5 ether);

        assertEq(tokenSanctions.balanceOf(admin), 95 ether);
        assertEq(tokenSanctions.balanceOf(user), 5 ether);
    }

    function testSetRestrictedUser() public {
        tokenSanctions.setRestricted(restrictedUser, true);
        assertEq(tokenSanctions.restricted(restrictedUser), true);
    }

    function testRestrictedCannotTransfer() public {
        tokenSanctions.transfer(restrictedUser, 5 ether);
        testSetRestrictedUser();

        vm.expectRevert();
        vm.prank(restrictedUser);
        tokenSanctions.transfer(admin, 5 ether);
    }

    function testRestrictedCannotReceive() public {
        testSetRestrictedUser();
        vm.expectRevert();
        tokenSanctions.transfer(restrictedUser, 5 ether);
    }
}
