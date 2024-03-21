pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "@solady/src/utils/FixedPointMathLib.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Test, console2} from "../lib/forge-std/src/Test.sol";

contract Pair is LPERC20, ReentrancyGuard {
    // using SafeMath  for uint;
    using UQ112x112 for uint224;
    using SafeTransferLib for address;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes32 private constant FLASH_LOAN = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;
    address public constant WETH = 0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    function getReserves()
        public
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "UniswapV2: TRANSFER_FAILED"
        );
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(
        uint balance0,
        uint balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "UniswapV2: OVERFLOW"
        );
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;

        bytes32 slot; // slot blockTimestampLast
        uint32 timestampLast; // == blockTimestampLast
        assembly {
            slot := blockTimestampLast.slot
            timestampLast := sload(slot)

            timeElapsed := sub(blockTimestamp, timestampLast) // overflow is desired
        }

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            unchecked {
                price0CumulativeLast +=
                uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                
                price1CumulativeLast +=
                uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(
        uint112 _reserve0,
        uint112 _reserve1
    ) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = FixedPointMathLib.sqrt(
                    uint(_reserve0) * _reserve1
                );
                uint rootKLast = FixedPointMathLib.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply() * (rootK - rootKLast);
                    uint denominator = (rootK * 5) + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external nonReentrant returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity =
                FixedPointMathLib.sqrt(amount0 * amount1) -
                MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = FixedPointMathLib.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    function safeMint(
        uint amountA,
        uint amountB,
        uint amountAMin,
        uint amountBMin,
        address to
    ) external payable nonReentrant returns (uint liquidity) {
        require(amountA > 0 && amountB > 0);
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            if (token0 == address(WETH)) {
                require(msg.value == amountA);
                IWETH(WETH).deposit{value: amountA}();
            } else {
                token0.safeTransferFrom(msg.sender, address(this), amountA);
            }
            if (token1 == address(WETH)) {
                require(msg.value == amountB);
                IWETH(WETH).deposit{value: amountB}();
            } else {
                token1.safeTransferFrom(msg.sender, address(this), amountB);
            }
            liquidity =
                FixedPointMathLib.sqrt(amountA * amountB) -
                MINIMUM_LIQUIDITY;
            _mint(to, liquidity);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            require(
                _reserve0 > 0 && _reserve1 > 0,
                "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
            );
            uint amountBOptimal = (amountA * _reserve1) / _reserve0;
            if (amountBOptimal <= amountB) {
                require(
                    amountBOptimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                amountB = amountBOptimal;
            } else {
                uint amountAOptimal = (amountB * _reserve0) / _reserve1;
                assert(amountAOptimal <= amountA);
                require(
                    amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                amountA = amountAOptimal;
            }
            if (token0 == address(WETH)) {
                require(msg.value >= amountA);
                IWETH(WETH).deposit{value: amountA}();
                (bool sent, ) = to.call{value: msg.value - amountA}("");
                require(sent, "Failed to send Ether");
            } else {
                token0.safeTransferFrom(msg.sender, address(this), amountA);
            }
            if (token1 == address(WETH)) {
                require(msg.value == amountB);
                IWETH(WETH).deposit{value: amountB}();
                (bool sent, ) = to.call{value: msg.value - amountB}("");
                require(sent, "Failed to send Ether");
            } else {
                token1.safeTransferFrom(msg.sender, address(this), amountB);
            }
            liquidity = FixedPointMathLib.min(
                (amountA * _totalSupply) / _reserve0,
                (amountB * _totalSupply) / _reserve1
            );
            _mint(to, liquidity);
        }
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amountA, amountB);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(
        address to
    ) external nonReentrant returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = (liquidity * balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(
            amount0 > 0 && amount1 > 0,
            "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED"
        );
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function safeBurn(
        uint amountIn,
        uint minAmountOut0,
        uint minAmountOut1,
        address to
    ) external nonReentrant returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));

        uint liquidity = amountIn;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = (liquidity * balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(
            amount0 > 0 && amount1 > 0,
            "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED"
        );
        require(
            amount0 > minAmountOut0 && amount1 > minAmountOut1,
            "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED"
        );
        _burn(msg.sender, liquidity);

        if (token0 == address(WETH)) {
            IWETH(WETH).withdraw(amount0);
            (bool sent, ) = to.call{value: amount0}("");
            require(sent, "Failed to send Ether");
        } else {
            _safeTransfer(_token0, to, amount0);
        }
        if (token1 == address(WETH)) {
            IWETH(WETH).withdraw(amount1);
            (bool sent, ) = to.call{value: amount1}("");
            require(sent, "Failed to send Ether");
        } else {
            _safeTransfer(_token1, to, amount1);
        }

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external nonReentrant {
        require(
            amount0Out > 0 || amount1Out > 0,
            "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "UniswapV2: INSUFFICIENT_LIQUIDITY"
        );

        uint balance0;
        uint balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0)
                IUniswapV2Callee(to).uniswapV2Call(
                    msg.sender,
                    amount0Out,
                    amount1Out,
                    data
                );
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out
            ? balance1 - (_reserve1 - amount1Out)
            : 0;
        require(
            amount0In > 0 || amount1In > 0,
            "UniswapV2: INSUFFICIENT_INPUT_AMOUNT"
        );
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
            uint balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
            require(
                balance0Adjusted * balance1Adjusted >=
                    (uint(_reserve0) * _reserve1) * 1000 ** 2,
                "UniswapV2: K"
            );
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function safeSwap(
        address _tokenIn,
        uint amountIn,
        uint amountOutMin,
        address to
    ) external payable nonReentrant {
        require(amountIn > 0 && amountOutMin > 0, "AMOUNT IS 0");
        require(_tokenIn == token0 || _tokenIn == token1, "WRONG TOKEN");

        address tokenIn = (_tokenIn == token0) ? token0 : token1;
        address tokenOut = (_tokenIn == token0) ? token1 : token0;

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        uint balance0;
        uint balance1;
        // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");

        // MY IMPLEMENTATION
        uint _kLast = uint(_reserve0) * _reserve1;
        uint fee = (amountIn * 3) / 1000;
        uint amount0In = (_tokenIn == token0) ? amountIn : 0;
        uint amount1In = (_tokenIn == token0) ? 0 : amountIn;
        if (tokenIn == address(WETH)) {
            require(msg.value == amountIn);
            IWETH(WETH).deposit{value: amountIn}();
        } else {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        }

        uint amountOut = (_tokenIn == token0)
            ? _reserve1 - (_kLast / (uint(_reserve0) + amountIn - fee)) - 1
            : _reserve0 - (_kLast / (uint(_reserve1) + amountIn - fee)) - 1;
        require(
            amountOut >= amountOutMin,
            "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        if (tokenOut == address(WETH)) {
            IWETH(WETH).withdraw(amountOut);
            (bool sent, ) = to.call{value: amountOut}("");
            require(sent, "Failed to send Ether");
        } else {
            _safeTransfer(tokenOut, to, amountOut);
        }

        uint amount0Out = (_tokenIn == token0) ? 0 : amountOut;
        uint amount1Out = (_tokenIn == token0) ? amountOut : 0;
        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "UniswapV2: INSUFFICIENT_LIQUIDITY"
        );

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
            uint balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
            require(
                balance0Adjusted * balance1Adjusted >=
                    (uint(_reserve0) * _reserve1) * 1000 ** 2,
                "UniswapV2: K"
            );
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }


    // force balances to match reserves
    function skim(address to) external nonReentrant {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(
            _token0,
            to,
            IERC20(_token0).balanceOf(address(this)) - reserve0
        );
        _safeTransfer(
            _token1,
            to,
            IERC20(_token1).balanceOf(address(this)) - reserve1
        );
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        return _maxFlashLoan(token);
    }

    function _maxFlashLoan(address token) internal view returns (uint256) {
        require(token == token0 || token == token1);
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) external view returns (uint256) {
        return _flashFee(token, amount);
    }

    function _flashFee(address token, uint256 amount) internal view returns (uint256) {
        require(token == token0 || token == token1);
        require(amount <= IERC20(token).balanceOf(address(this)));
        return (amount * 3) / 1000;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        require(token == token0 || token == token1);
        require(amount <= IERC20(token).balanceOf(address(this)));

        uint balance = IERC20(token).balanceOf(address(this));
        uint fee = _flashFee(token, amount);
        _safeTransfer(token, address(receiver), amount);

        require(receiver.onFlashLoan(msg.sender, token, amount, fee, data) == FLASH_LOAN);

        token.safeTransferFrom(address(receiver), address(this), amount + fee);
        require(IERC20(token).balanceOf(address(this)) >= balance + fee);
        return true;
    }
}
