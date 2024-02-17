// SPDX-License-Identifier: UNLICENSED

import {LinearBondingCurve} from "../src/LinearBondingCurve.sol";
import {Token} from "../src/LinearBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

pragma solidity 0.8.20;

contract LinearBondingCurveTest is Test {
    LinearBondingCurve public linearBondingCurve;
    Token public token;
    address public user2 = address(2);
    uint256 public decimals;

    function setUp() public {
        linearBondingCurve = new LinearBondingCurve();
        token = linearBondingCurve.token();
        decimals = linearBondingCurve.decimals();
    }

    receive() external payable {}

    function testInitialValues() public {
        assertEq(token.totalSupply(), 0);
        assertEq(linearBondingCurve.supply(), 0);
    }

    function testFirstBuy() public {
        deal(address(this), 15 ether);
        linearBondingCurve.buyToken{value: 15 ether}(5 * decimals);

        assertEq(token.totalSupply(), linearBondingCurve.supply());
        assertEq(linearBondingCurve.supply(), 5 * decimals);
        assertEq(token.balanceOf(address(this)), 5 * decimals);
        assertEq(token.balanceOf(address(linearBondingCurve)), 0);
    }

    function testSecondBuy() public {
        testFirstBuy();

        hoax(user2, 13 ether);
        linearBondingCurve.buyToken{value: 13 ether}(2 * decimals);

        assertEq(token.totalSupply(), linearBondingCurve.supply());
        assertEq(linearBondingCurve.supply(), 7 * decimals);
        assertEq(token.balanceOf(user2), 2 * decimals);
        assertEq(token.balanceOf(address(linearBondingCurve)), 0);
    }

    function testSell() public {
        testSecondBuy();
        skip(601);

        token.approve(address(linearBondingCurve), 5 * decimals);
        linearBondingCurve.sellToken(1 * decimals);

        assertEq(address(this).balance, 7 ether);
        assertEq(token.totalSupply(), linearBondingCurve.supply());
        assertEq(linearBondingCurve.supply(), 6 * decimals);
        assertEq(token.balanceOf(address(this)), 4 * decimals);
        assertEq(token.balanceOf(address(linearBondingCurve)), 0);
    }
}
