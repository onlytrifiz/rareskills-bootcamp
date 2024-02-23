// SPDX-License-Identifier: UNLICENSED

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity 0.8.20;

contract TokenSanctions is ERC20 {
    mapping(address => bool) public restricted;
    address public admin;

    event Restricted(address restricted);
    event Unrestricted(address unrestricted);

    constructor() ERC20("TokenSanctions", "TS") {
        _mint(msg.sender, 100 ether);
        admin = msg.sender;
    }

    function setRestricted(address _address, bool _restricted) public {
        require(msg.sender == admin);

        restricted[_address] = _restricted;
        if (_restricted == true) {
            emit Restricted(_address);
        } else {
            emit Unrestricted(_address);
        }
        
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(!restricted[msg.sender]);
        require(!restricted[to]);

        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    // added after meeting revision
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(!restricted[from], "Restricted user cannot transfer");
        require(!restricted[to], "Restricted user cannot receive");

        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

}
