// SPDX-License-Identifier: UNLICENSED

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Test, console2} from "forge-std/Test.sol";

pragma solidity 0.8.20;

contract Token is ERC20 {

    address public admin;

    constructor() ERC20("Token", "TKN") {
        admin = msg.sender;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == admin);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        require(msg.sender == admin);
        _burn(from, amount);
    }

}

contract LinearBondingCurve {
    using SafeERC20 for Token;
    Token public token;

    uint256 public supply;
    uint256 public reserve;

    event Bought(address indexed buyer, uint256 tokenAmount, uint256 ethPaid);
    event Sold(address indexed seller, uint256 tokenAmount, uint256 ethReceived);

    constructor() {
        token = new Token();
    }

    function buyToken(uint256 amountMin) public payable {
        uint256 currentSupply = supply;
        supply = currentSupply + amountMin;

        // Reserve Ratio (RR) = Reserve (R) / (Supply (S) x Price (P))
        // R = (S * P) * RR
        // R = (S * P) * 0.5
        // since S == P
        // R = (S^2) * 0.5
        reserve = ((currentSupply ** 2) / 10 ** 18) / 2;
        uint256 newReserve = ((supply ** 2) / 10 ** 18) / 2;
        uint256 ethersToSend = newReserve - reserve;
        reserve = newReserve;

        require(msg.value >= ethersToSend);

        if (msg.value == ethersToSend) {
            token.mint(msg.sender, amountMin);

            emit Bought(msg.sender, amountMin, msg.value);
        }
        else {
            token.mint(msg.sender, amountMin);
            (bool sent,) = msg.sender.call{value: msg.value - ethersToSend}("");
            require(sent, "Failed to send Ether");

            emit Bought(msg.sender, amountMin, ethersToSend);
        }
        
    }

    function sellToken(uint256 amount, uint256 minEth) public {
        uint256 currentSupply = supply;
        supply = currentSupply - amount;

        reserve = ((currentSupply ** 2) / 10 ** 18) / 2;
        uint256 newReserve = ((supply ** 2) / 10 ** 18) / 2;
        uint256 ethersToSend = reserve - newReserve;
        reserve = newReserve;

        require(ethersToSend >= minEth);

        token.safeTransferFrom(msg.sender, address(this), amount);
        token.burn(address(this), amount);
        (bool sent,) = msg.sender.call{value: ethersToSend}("");
        require(sent, "Failed to send Ether");

        emit Sold(msg.sender, amount, ethersToSend);

    }
}
