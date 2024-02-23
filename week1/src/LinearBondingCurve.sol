// SPDX-License-Identifier: UNLICENSED

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

pragma solidity 0.8.20;

contract Token is ERC20 {
    address public admin;

    constructor() ERC20("Token", "TKN") {
        admin = msg.sender;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function decimals() public view override returns (uint8) {
        return 18;
    }
}

contract LinearBondingCurve {
    Token public token;

    uint256 public supply;
    mapping(address => uint256) public lastPurchased;
    uint256 public decimals;

    constructor() {
        token = new Token();
        decimals = 10 ** token.decimals();
    }

    function buyToken(uint256 amount) public payable {
        uint256 currentSupply = supply;
        supply = currentSupply + amount;

        uint256 ethersToSend;

        // Reserve Ratio (RR) = Reserve (R) / (Supply (S) x Price (P))
        // R = (S * P) * RR
        // R = (S * P) * 0.5
        // S == P
        // reserve = (currentSupply * currentSupply) * 0.5
        // newReserve = (supply * supply) * 0.5
        // ethersToSend = newReserve - reserve
        // reserve = newReserve

        for (uint256 i = currentSupply / decimals + 1; i <= supply / decimals; i++) {
            ethersToSend += i;
        }

        require(msg.value == ethersToSend * 1 ether);

        token.mint(msg.sender, amount);
        lastPurchased[msg.sender] = block.timestamp;
    }

    function sellToken(uint256 amount) public {
        require(block.timestamp > lastPurchased[msg.sender] + 600);
        uint256 currentSupply = supply;
        supply = currentSupply - amount;

        uint256 ethersToSend;
        for (uint256 i = supply / decimals + 1; i <= currentSupply / decimals; i++) {
            ethersToSend += i;
        }

        token.transferFrom(msg.sender, address(this), amount);
        token.burn(address(this), amount);
        (bool sent,) = msg.sender.call{value: ethersToSend * 1 ether}("");
        require(sent, "Failed to send Ether");
    }
}
