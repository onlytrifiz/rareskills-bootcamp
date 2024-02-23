// SPDX-License-Identifier: UNLICENSED

import {LinearBondingCurve} from "../src/LinearBondingCurve.sol";
import {Token} from "../src/LinearBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

pragma solidity 0.8.20;

contract LinearBondingCurveTest is Test {
    LinearBondingCurve public linearBondingCurve;
    Token public token;
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        linearBondingCurve = new LinearBondingCurve();
        token = linearBondingCurve.token();
    }

    receive() external payable {}

    function testInitialValues() public {
        assertEq(token.totalSupply(), 0);
        assertEq(linearBondingCurve.supply(), 0);
        assertEq(user1.balance, 0);
        assertEq(user2.balance, 0);
    }

    function testFirstBuy() public {
        hoax(user1, 12.5 ether);
        linearBondingCurve.buyToken{value: 12.5 ether}(5 ether);

        assertEq(token.totalSupply(), linearBondingCurve.supply());
        assertEq(linearBondingCurve.supply(), 5 ether);
        assertEq(token.balanceOf(user1), 5 ether);
        assertEq(token.balanceOf(address(linearBondingCurve)), 0);
    }

    function testSecondBuy() public {
        testFirstBuy();

        hoax(user2, 12 ether);
        linearBondingCurve.buyToken{value: 12 ether}(2 ether);

        assertEq(token.totalSupply(), linearBondingCurve.supply());
        assertEq(linearBondingCurve.supply(), 7 ether);
        assertEq(token.balanceOf(user2), 2 ether);
        assertEq(token.balanceOf(address(linearBondingCurve)), 0);
    }

    function testSell() public {
        testSecondBuy();

        vm.startPrank(user1);
        token.approve(address(linearBondingCurve), 5 ether);
        linearBondingCurve.sellToken(1 ether, 6 ether);

        assertEq(user1.balance, 6.5 ether);
        assertEq(token.totalSupply(), linearBondingCurve.supply());
        assertEq(linearBondingCurve.supply(), 6 ether);
        assertEq(token.balanceOf(user1), 4 ether);
        assertEq(token.balanceOf(address(linearBondingCurve)), 0);
    }
}
