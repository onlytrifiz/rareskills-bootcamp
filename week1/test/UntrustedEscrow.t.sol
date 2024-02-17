// SPDX-License-Identifier: UNLICENSED

import {UntrustedEscrow} from "../src/UntrustedEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NonStandardERC20} from "../src/NonStandardERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

pragma solidity 0.8.20;

contract Token is ERC20 {
    using SafeERC20 for ERC20;

    constructor() ERC20("Token", "TKN") {
        _mint(msg.sender, 100 ether);
    }
}

contract TransferFeeToken is NonStandardERC20 {
    constructor() NonStandardERC20("TransferFeeToken", "TFT") {
        _mint(msg.sender, 100 ether);
    }
}

contract UntrustedEscrowTest is Test {
    UntrustedEscrow public untrustedEscrow;
    Token public token;
    TransferFeeToken public transferFeeToken;

    address public buyer = address(this);
    address public seller = address(1);

    function setUp() public {
        untrustedEscrow = new UntrustedEscrow();
        token = new Token();
        transferFeeToken = new TransferFeeToken();
    }

    function testCheckBalance() public {
        assertEq(token.balanceOf(buyer), 100 ether);
    }

    function testBuy() public {
        token.approve(address(untrustedEscrow), 20 ether);
        untrustedEscrow.buy(seller, token, 10 ether);
        untrustedEscrow.buy(seller, token, 10 ether);
        assertEq(token.balanceOf(address(untrustedEscrow)), 20 ether);
        assertEq(token.balanceOf(buyer), 80 ether);

        (,, uint256 amount,, uint256 orderId) = untrustedEscrow.orders(seller, 1);
        console2.log(orderId);
        console2.log(amount);
    }

    function testWithdraw() public {
        testBuy();
        vm.warp(block.timestamp + 4 days);
        vm.prank(seller);
        untrustedEscrow.withdraw(1);
        assertEq(token.balanceOf(address(untrustedEscrow)), 10 ether);
        assertEq(token.balanceOf(buyer), 80 ether);
        assertEq(token.balanceOf(seller), 10 ether);
    }

    function testAlreadyWithdrawn() public {
        testWithdraw();

        vm.prank(seller);
        vm.expectRevert("Already withdrawn");
        untrustedEscrow.withdraw(1);
    }

    function testEarlyWithdraw() public {
        testBuy();

        vm.prank(seller);
        vm.expectRevert("You must wait 3 days");
        untrustedEscrow.withdraw(1);
    }

    function testTransferFeeTokenBuy() public {
        transferFeeToken.approve(address(untrustedEscrow), 10 ether);
        untrustedEscrow.buy(seller, transferFeeToken, 10 ether);
        assertEq(transferFeeToken.balanceOf(address(untrustedEscrow)), 9.9 ether);
        assertEq(transferFeeToken.balanceOf(buyer), 90 ether);

        (,, uint256 amount,, uint256 orderId) = untrustedEscrow.orders(seller, 0);
        console2.log(orderId);
        console2.log(amount);
    }

    function testTransferFeeTokenWithdraw() public {
        testTransferFeeTokenBuy();
        vm.warp(block.timestamp + 4 days);
        vm.prank(seller);
        untrustedEscrow.withdraw(0);
        assertEq(transferFeeToken.balanceOf(address(untrustedEscrow)), 0 ether);
        assertEq(transferFeeToken.balanceOf(buyer), 90 ether);
        assertEq(transferFeeToken.balanceOf(seller), 9.801 ether);
    }
}
