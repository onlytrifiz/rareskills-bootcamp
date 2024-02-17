// SPDX-License-Identifier: UNLICENSED

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity 0.8.20;

contract TokenGodMode is ERC20 {
    address public god;

    constructor() ERC20("TokenGodMode", "TGM") {
        _mint(msg.sender, 100 ether);
        god = msg.sender;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        address spender = _msgSender();

        if (spender == god) {
            _transfer(from, to, value);
        } else {
            _spendAllowance(from, spender, value);
            _transfer(from, to, value);
        }

        return true;
    }
}
