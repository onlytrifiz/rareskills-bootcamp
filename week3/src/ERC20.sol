pragma solidity ^0.8.0;

import {ERC20} from "@solady/src/tokens/ERC20.sol";

contract LPERC20 is ERC20 {

    function name() public pure override returns (string memory) {
        return 'Uniswap V2';
    }

    function symbol() public pure override returns (string memory) {
        return 'UNI-V2';
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

}
