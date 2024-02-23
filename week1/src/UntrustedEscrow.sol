// SPDX-License-Identifier: UNLICENSED

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity 0.8.20;

contract UntrustedEscrow {
    using SafeERC20 for IERC20;

    struct Order {
        address buyer;
        IERC20 token;
        uint256 amount;
        uint256 timestamp;
        uint256 id;
    }

    mapping(address => Order[]) public orders;

    event NewOrder(
        address indexed seller,
        address indexed buyer,
        uint256 timestamp,
        uint256 id
    );

    event OrderFulfilled(
        address indexed seller,
        uint256 timestamp,
        uint256 id
    );

    function buy(address seller, IERC20 token, uint256 amount) public {
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 id = orders[seller].length;

        Order memory newOrder = Order({
            buyer: msg.sender,
            token: token,
            amount: balanceAfter - balanceBefore,
            timestamp: block.timestamp,
            id: id
        });
        orders[seller].push(newOrder);

        emit NewOrder(seller, msg.sender, block.timestamp, id);
    }

    function withdraw(uint256 id) public {
        require(orders[msg.sender][id].timestamp + 3 days < block.timestamp, "You must wait 3 days");
        require(orders[msg.sender][id].amount > 0, "Already withdrawn");
        uint256 amount = orders[msg.sender][id].amount;
        orders[msg.sender][id].amount = 0;

        orders[msg.sender][id].token.safeTransfer(msg.sender, amount);   

        emit OrderFulfilled(msg.sender, block.timestamp, id);
    }
}
