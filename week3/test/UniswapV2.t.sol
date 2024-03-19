// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";
import {WETH} from "../src/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import '@solady/src/utils/FixedPointMathLib.sol';

contract Token is Test, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/// @title Test contract to test my custom implementation of UniswapV2
contract UniswapV2Test is Test, IERC3156FlashBorrower {
    Factory public factory;
    //Router public router;
    Token public token0;
    Token public token1;
    Pair public pair;
    WETH public weth;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    function setUp() public {
        factory = new Factory(address(this));
        //router = new UniswapV2Router02(address(factory), address(1));
        token0 = new Token("Token0", "TKN0");
        token0.mint(address(this), 100 ether);
        token1 = new Token("Token1", "TKN1");
        token1.mint(address(this), 100 ether);
        weth = new WETH();
        deal(address(this), 100 ether);
        weth.deposit{value: 10 ether}();
    }

    receive() external payable {

    }
    
    function testCreatePair() public {
        pair = Pair(payable(factory.createPair(address(token1), address(token0))));
        assertEq(factory.allPairsLength(), 1);
    }

    function testCreatePairWETH() public {
        pair = Pair(payable(factory.createPair(address(weth), address(token1))));
        assertEq(factory.allPairsLength(), 1);
    }

     /// @notice Add liquidity token0/token1 using function without safety checks
    function testAddLiquidity() public {
        testCreatePair();

        uint amount0 = 10 ether;
        uint amount1 = 10 ether;
        uint lpOut = FixedPointMathLib.sqrt(amount0 * amount1);

        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        pair.mint(address(this));
        assertEq(pair.balanceOf(address(this)), lpOut - MINIMUM_LIQUIDITY);
    }

    /// @notice Add token0/token1 liquidity using my custom mint function
    function testSafeAddLiquidity() public {
        testCreatePair();

        uint amount0 = 10 ether;
        uint amount1 = 10 ether;
        uint lpOut = FixedPointMathLib.sqrt(amount0 * amount1);

        token0.approve(address(pair), amount0);
        token1.approve(address(pair), amount1);
        pair.safeMint(amount0, amount1, amount0, amount1, address(this));
        assertEq(pair.balanceOf(address(this)), lpOut - MINIMUM_LIQUIDITY);
    }

    /// @notice Add more token0/token1 liquidity using my custom mint function
    function testAddMoreSafeLiquidity() public {
        testAddLiquidity();

        uint amount0 = 2 ether;
        uint amount1 = 0.5 ether;

        token0.approve(address(pair), amount0);
        token1.approve(address(pair), amount1);
        pair.safeMint(amount0, amount1, 0 ether, 0 ether, address(this));

    }

    /// @notice Add liquidity WETH/token1 using function without safety checks
    function testAddLiquidityWETH() public {
        testCreatePairWETH();

        uint amountETH = 10 ether;
        uint amount1 = 9 ether;
        uint lpOut = FixedPointMathLib.sqrt(amountETH * amount1);

        weth.transfer(address(pair), amountETH);
        token1.transfer(address(pair), amount1);
        pair.mint(address(this));
        assertEq(pair.balanceOf(address(this)), lpOut - MINIMUM_LIQUIDITY);
    }

    /// @notice Add ETH/token1 liquidity using my custom mint function
    function testSafeAddLiquidityWETH() public {
        testCreatePairWETH();

        uint amountETH = 10 ether;
        uint amount1 = 10 ether;
        uint lpOut = FixedPointMathLib.sqrt(amountETH * amount1);

        token1.approve(address(pair), amount1);
        pair.safeMint{value: amountETH}(amountETH, amount1, amountETH, amount1, address(this));
        assertEq(pair.balanceOf(address(this)), lpOut - MINIMUM_LIQUIDITY);
    }

    /// @notice Add more ETH/token1 liquidity using my custom mint function
    function testSafeAddMoreLiquidityWETH() public {
        testSafeAddLiquidityWETH();

        uint amountETH = 1.5 ether;
        uint amount1 = 1 ether;

        token1.approve(address(pair), amount1);
        pair.safeMint{value: amountETH}(amountETH, amount1, 0, 0, address(this));

        /* console2.log(newBalanceWETH - balanceWETH);
        console2.log(newBalance1 - balance1);
        console2.log("Old LP", LPAmount);
        console2.log("New LP", newLPAmount);
        console2.log(newLPAmount - LPAmount);
        console2.log("pair balance: ", address(pair).balance); */
    }

    /// @notice Swap 2e18 token0 using swap function without safety checks
    function testSwap() public {
        testAddLiquidity();
        bytes memory data = "";

        uint swapAmount = 2 ether;
        uint minAmountOut = 1 ether;
        uint userBalance0 = token0.balanceOf(address(this));
        uint userBalance1 = token1.balanceOf(address(this));
        uint pairBalance0 = token0.balanceOf(address(pair));
        uint pairBalance1 = token1.balanceOf(address(pair));

        token0.transfer(address(pair), swapAmount);
        pair.swap(0, minAmountOut, address(this), data);
        assertEq(token0.balanceOf(address(this)), userBalance0 - swapAmount);
        assertEq(token1.balanceOf(address(this)), userBalance1 + minAmountOut);
        assertEq(token0.balanceOf(address(pair)), pairBalance0 + swapAmount);
        assertEq(token1.balanceOf(address(pair)), pairBalance1 - minAmountOut);
    }

    /// @notice Swap 1e18 token0 using my custom swap function
    function testSwapTokensForTokens() public {
        testAddLiquidity();

        uint userBalance0 = token0.balanceOf(address(this));
        uint userBalance1 = token1.balanceOf(address(this));
        uint pairBalance0 = token0.balanceOf(address(pair));
        uint pairBalance1 = token1.balanceOf(address(pair));
        uint swapAmount = 1 ether;
        uint minAmountOut = (swapAmount * 9) / 10;

        token0.approve(address(pair), swapAmount);
        pair.safeSwap(address(token0), swapAmount, minAmountOut, address(this));

        assertEq(token0.balanceOf(address(this)), userBalance0 - swapAmount);
        assertGt(token1.balanceOf(address(this)), userBalance1 + minAmountOut);
        assertEq(token0.balanceOf(address(pair)), pairBalance0 + swapAmount);
        assertLt(token1.balanceOf(address(pair)), pairBalance1 - minAmountOut);

        console2.log(token1.balanceOf(address(this)));
    }

    /// @notice Swap 1e18 WETH using my custom swap function
    function testSwapETHForTokens() public {
        testAddLiquidityWETH();

        uint userBalanceETH = address(this).balance;
        uint userBalanceToken = token1.balanceOf(address(this));
        uint pairBalanceWETH = weth.balanceOf(address(pair));
        uint pairBalanceToken = token1.balanceOf(address(pair));
        uint swapAmount = 1 ether;
        uint minAmountOut = (1 ether * 8) / 10;

        pair.safeSwap{value: swapAmount}(address(weth), swapAmount, minAmountOut, address(this));
        
        assertEq(address(this).balance, userBalanceETH - swapAmount);
        assertGt(token1.balanceOf(address(this)), userBalanceToken + minAmountOut);
        assertEq(weth.balanceOf(address(pair)), pairBalanceWETH + swapAmount);
        assertLt(token1.balanceOf(address(pair)), pairBalanceToken - minAmountOut);
    }

    /// @notice Swap 1e18 Tokens for ETH using my custom swap function
    function testSafeSwapTokensforETH() public {
        testAddLiquidityWETH();

        uint userBalanceETH = address(this).balance;
        uint userBalanceToken = token1.balanceOf(address(this));
        uint pairBalanceWETH = weth.balanceOf(address(pair));
        uint pairBalanceToken = token1.balanceOf(address(pair));
        uint swapAmount = 1 ether;
        uint minAmountOut = (1 ether * 8) / 10;

        token1.approve(address(pair), swapAmount);
        pair.safeSwap(address(token1), swapAmount, minAmountOut, address(this));
        
        assertEq(token1.balanceOf(address(this)), userBalanceToken - swapAmount);
        assertGt(address(this).balance, userBalanceETH + minAmountOut);
        assertEq(token1.balanceOf(address(pair)), pairBalanceToken + swapAmount);
        assertLt(weth.balanceOf(address(pair)), pairBalanceWETH - minAmountOut);
    }

    /// @notice Remove token0/token1 liquidity using function without safety checks
    function testRemoveLiquidity() public {
        testAddLiquidity();

        IERC20 tokenA = token0;
        IERC20 tokenB = token1;
        uint userBalance0 = tokenA.balanceOf(address(this));
        uint userBalance1 = tokenB.balanceOf(address(this));
        uint pairBalance0 = tokenA.balanceOf(address(pair));
        uint pairBalance1 = tokenB.balanceOf(address(pair));
        console2.log("Balance A :", tokenA.balanceOf(address(pair)));
        console2.log("Balance B :", tokenB.balanceOf(address(pair)));

        pair.transfer(address(pair), pair.balanceOf(address(this)));
        (uint amountA, uint amountB) = pair.burn(address(this));

        assertEq(tokenA.balanceOf(address(this)), userBalance0 + amountA);
        assertEq(tokenB.balanceOf(address(this)), userBalance1 + amountB);
        assertEq(tokenA.balanceOf(address(pair)), pairBalance0 - amountA);
        assertEq(tokenB.balanceOf(address(pair)), pairBalance1 - amountB);
        console2.log("Balance A left:", tokenA.balanceOf(address(pair)));
        console2.log("Balance B left:", tokenB.balanceOf(address(pair)));
    }

    /// @notice Remove token0/token1 liquidity using my custom burn function
    function testSafeRemoveLiquidity() public {
        testAddLiquidity();

        IERC20 tokenA = token0;
        IERC20 tokenB = token1;
        uint userBalance0 = tokenA.balanceOf(address(this));
        uint userBalance1 = tokenB.balanceOf(address(this));
        uint pairBalance0 = tokenA.balanceOf(address(pair));
        uint pairBalance1 = tokenB.balanceOf(address(pair));
        console2.log("Balance A :", tokenA.balanceOf(address(pair)));
        console2.log("Balance B :", tokenB.balanceOf(address(pair)));

        pair.approve(address(pair), pair.balanceOf(address(this)));
        (uint amountA, uint amountB) = pair.safeBurn(pair.balanceOf(address(this)), 0, 0, address(this));

        assertEq(tokenA.balanceOf(address(this)), userBalance0 + amountA);
        assertEq(tokenB.balanceOf(address(this)), userBalance1 + amountB);
        assertEq(tokenA.balanceOf(address(pair)), pairBalance0 - amountA);
        assertEq(tokenB.balanceOf(address(pair)), pairBalance1 - amountB);
        console2.log("Balance A left:", tokenA.balanceOf(address(pair)));
        console2.log("Balance B left:", tokenB.balanceOf(address(pair)));

    }

    /// @notice Remove ETH/token1 liquidity using my custom burn function
    function testSafeRemoveLiquidityETH() public {
        testSafeAddLiquidityWETH();

        uint userBalance0 = address(this).balance;
        uint userBalance1 = token1.balanceOf(address(this));
        uint pairBalance0 = weth.balanceOf(address(pair));
        uint pairBalance1 = token1.balanceOf(address(pair));
        console2.log("Balance A :", weth.balanceOf(address(pair)));
        console2.log("Balance B :", token1.balanceOf(address(pair)));

        pair.approve(address(pair), pair.balanceOf(address(this)));
        (uint amountA, uint amountB) = pair.safeBurn(pair.balanceOf(address(this)), 0, 0, address(this));

        assertEq(address(this).balance, userBalance0 + amountA);
        assertEq(token1.balanceOf(address(this)), userBalance1 + amountB);
        assertEq(weth.balanceOf(address(pair)), pairBalance0 - amountA);
        assertEq(token1.balanceOf(address(pair)), pairBalance1 - amountB);
        console2.log("Balance A left:", weth.balanceOf(address(pair)));
        console2.log("Balance B left:", token1.balanceOf(address(pair)));

    }

    /// @notice Swap 1e18 token0 using my custom swap function
    function testSafeSwap() public {
        testAddLiquidity();

        IERC20 tokenIn = token1;
        IERC20 tokenOut = token0;
        uint swapAmount = 1 ether;
        uint minAmountOut = (swapAmount * 8) / 10;

        uint userBalance0 = tokenIn.balanceOf(address(this));
        uint userBalance1 = tokenOut.balanceOf(address(this));
        uint pairBalance0 = tokenIn.balanceOf(address(pair));
        uint pairBalance1 = tokenOut.balanceOf(address(pair));

        tokenIn.approve(address(pair), swapAmount);
        pair.safeSwap(address(tokenIn), swapAmount, minAmountOut, address(this));

        assertEq(tokenIn.balanceOf(address(this)), userBalance0 - swapAmount);
        assertGt(tokenOut.balanceOf(address(this)), userBalance1 + minAmountOut);
        assertEq(tokenIn.balanceOf(address(pair)), pairBalance0 + swapAmount);
        assertLt(tokenOut.balanceOf(address(pair)), pairBalance1 - minAmountOut);
    }

    /// @notice Swap 1e18 WETH using my custom swap function
    function testSafeSwapWETHIn() public {
        testAddLiquidityWETH();

        uint userBalanceETH = address(this).balance;
        uint userBalanceToken = token1.balanceOf(address(this));
        uint pairBalanceWETH = weth.balanceOf(address(pair));
        uint pairBalanceToken = token1.balanceOf(address(pair));
        uint swapAmount = 1 ether;
        uint minAmountOut = (swapAmount * 8) / 10;

        pair.safeSwap{value: swapAmount}(address(weth), swapAmount, minAmountOut, address(this));
        
        assertEq(address(this).balance, userBalanceETH - swapAmount);
        assertGt(token1.balanceOf(address(this)), userBalanceToken + minAmountOut);
        assertEq(weth.balanceOf(address(pair)), pairBalanceWETH + swapAmount);
        assertLt(token1.balanceOf(address(pair)), pairBalanceToken - minAmountOut);
    }

    /// @notice Swap 1e18 Tokens for ETH using my custom swap function
    function testSafeSwapWETHOut() public {
        testAddLiquidityWETH();

        uint userBalanceETH = address(this).balance;
        uint userBalanceToken = token1.balanceOf(address(this));
        uint pairBalanceWETH = weth.balanceOf(address(pair));
        uint pairBalanceToken = token1.balanceOf(address(pair));
        uint swapAmount = 1 ether;
        uint minAmountOut = (1 ether * 8) / 10;

        token1.approve(address(pair), swapAmount);
        pair.safeSwap(address(token1), swapAmount, minAmountOut, address(this));
        
        assertEq(token1.balanceOf(address(this)), userBalanceToken - swapAmount);
        assertGt(address(this).balance, userBalanceETH + minAmountOut);
        assertEq(token1.balanceOf(address(pair)), pairBalanceToken + swapAmount);
        assertLt(weth.balanceOf(address(pair)), pairBalanceWETH - minAmountOut);
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32) {
        require(msg.sender == address(pair), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: Untrusted loan initiator");

        // (parsedData) = abi. decode(data, (DataTypes)) ;
        // do something with the flashloan

        // allow the flash loan to take the tokens back
       

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function testFlashLoan() public {
        testAddLiquidity();

        pair.flashLoan(IERC3156FlashBorrower(this), address(token0), 1 ether, "");
    }

}
