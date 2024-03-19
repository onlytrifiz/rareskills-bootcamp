// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
import {UniswapV2Pair} from "@uniswap/v2-core/contracts/UniswapV2Pair.sol";
import {IERC20} from "@openzeppelin-contracts-06/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin-contracts-06/contracts/token/ERC20/ERC20.sol";
//import {UniswapV2Router02} from "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";

contract Token is ERC20 {
    constructor() ERC20() public {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract FactoryTest {
    UniswapV2Factory public factory;
    Token public token0;
    Token public token1;
    UniswapV2Pair public pair;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    function setUp() public {
        factory = new UniswapV2Factory(address(this));
        token0 = new Token();
        token0.mint(address(this), 100 ether);
        token1 = new Token();
        token1.mint(address(this), 100 ether);
        require(token0.balanceOf(address(this)) == 100 ether);
        require(token1.balanceOf(address(this)) == 100 ether);
    }
    
    function testCreatePair() public {
        pair = UniswapV2Pair(factory.createPair(address(token0), address(token1)));
        require(factory.allPairsLength() == 1);
    }

    function testAddLiquidity() public {
        testCreatePair();

        token0.transfer(address(pair), 10 ether);
        token1.transfer(address(pair), 10 ether);
        pair.mint(address(this));
        require(pair.balanceOf(address(this)) == 10 ether - MINIMUM_LIQUIDITY);
    }

    function testSwap() public {
        testAddLiquidity();
        bytes memory data = "";

        token0.transfer(address(pair), 2 ether);
        pair.swap(0, 1 ether, address(this), data);
        require(token0.balanceOf(address(this)) == 88 ether);
        require(token1.balanceOf(address(this)) == 91 ether);
        require(token0.balanceOf(address(pair)) == 12 ether);
        require(token1.balanceOf(address(pair)) == 9 ether);
    }

    function testRemoveLiquidity() public {
        testSwap();

        pair.transfer(address(pair), pair.balanceOf(address(this)));
        pair.burn(address(this));
        require(token0.balanceOf(address(this)) == 99999999999999998800);
        require(token1.balanceOf(address(this)) == 99999999999999999100);
    }

}

