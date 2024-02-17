// SPDX-License-Identifier: UNLICENSED

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity 0.8.20;

contract TokenSanctions is ERC20 {
    mapping(address => bool) public restricted;
    address public admin;

    constructor() ERC20("TokenSanctions", "TS") {
        _mint(msg.sender, 100 ether);
        admin = msg.sender;
    }

    function setRestricted(address _address, bool _restricted) public {
        require(msg.sender == admin);

        restricted[_address] = _restricted;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(!restricted[msg.sender]);
        require(!restricted[to]);

        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
}
