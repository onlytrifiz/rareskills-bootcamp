// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2ERC20} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract Token is Test, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/// @title Test contract to get exact values of UniswapV2 router and compare them with my implementation
contract FactoryTest is Test {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IUniswapV2Pair public pair;
    Token public token0;
    Token public token1;
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    function setUp() public {
        factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        token0 = new Token("Token0", "TKN0");
        token0.mint(address(this), 100 ether);
        token1 = new Token("Token1", "TKN1");
        token1.mint(address(this), 100 ether);
    }

    function testCreatePair() public {
        pair = IUniswapV2Pair(
            factory.createPair(address(token0), address(token1))
        );
    }

    function testAddLiquidity() public {
        testCreatePair();

        token0.approve(address(router), 100 ether);
        token1.approve(address(router), 100 ether);
        router.addLiquidity(
            address(token0),
            address(token1),
            9 ether,
            10 ether,
            0 ether,
            0 ether,
            address(this),
            block.timestamp + 100
        );
    }

    /// @notice Swap 1e18 token0 UniswapV2 router
    function testSwap() public {
        testAddLiquidity();

        address t0 = address(token0);
        address t1 = address(token1);
        address[] memory path = new address[](2); // Declare path as a dynamically-sized array
        path[0] = t0;
        path[1] = t1;
        router.swapExactTokensForTokens(
            1 ether,
            0 ether,
            path,
            address(this),
            block.timestamp + 100
        );
        console2.log(token1.balanceOf(address(this)));

        (uint balance0, uint balance1, ) = pair.getReserves();
        //console2.log(balance0);
        //console2.log(balance1);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();

        ERC20 tokenA = token0;
        ERC20 tokenB = token1;
        uint userBalance0 = tokenA.balanceOf(address(this));
        uint userBalance1 = tokenB.balanceOf(address(this));
        uint pairBalance0 = tokenA.balanceOf(address(pair));
        uint pairBalance1 = tokenB.balanceOf(address(pair));
        console2.log("Balance A :", tokenA.balanceOf(address(pair)));
        console2.log("Balance B :", tokenB.balanceOf(address(pair)));

        pair.approve(address(router), pair.balanceOf(address(this)));
        (uint amountA, uint amountB) = router.removeLiquidity(address(tokenA), address(tokenB), pair.balanceOf(address(this)), 0, 0, address(this), 99999999999999999);

        console2.log("Balance A left:", tokenA.balanceOf(address(pair)));
        console2.log("Balance B left:", tokenB.balanceOf(address(pair)));
        assertEq(tokenA.balanceOf(address(this)), userBalance0 + amountA);
        assertEq(tokenB.balanceOf(address(this)), userBalance1 + amountB);
        assertEq(tokenA.balanceOf(address(pair)), pairBalance0 - amountA);
        assertEq(tokenB.balanceOf(address(pair)), pairBalance1 - amountB);
    }



}
