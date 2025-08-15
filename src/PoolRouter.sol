// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPoolFactory} from "./interfaces/IPoolFactory.sol";
import {ILiquidityPool} from "./interfaces/ILiquidityPool.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PoolRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IPoolFactory public factory;
    address public immutable WETH;
    uint256 private constant factor = 100000;
    uint256 public ownerFees = 100; //.1%

    event LogSwapETHForTokens(address _sender, uint256 _amountIn, address _tokenOut, address _poolAddress);
    event LogSwapTokensForETH(address _sender, uint256 _amountIn, address _tokenIn, address _poolAddress);
    event LogAddLiquidityETH(
        address _sender, address _token, uint256 _amountToken, address _poolAddress, uint256 _shares
    );
    event LogRemoveLiquidity(
        address _sender,
        address _tokenA,
        address _tokenB,
        uint256 _shares,
        uint256 _amountA,
        uint256 _amountB,
        address poolAddress
    );
    event LogRemoveLiquidityETH(
        address _sender, address _token, uint256 _shares, uint256 _amountToken, uint256 _amountETH
    );

    event LogAddTokenToTokenLiquidity(
        address _sender, address _tokenA, address _tokenB, uint256 amountA, uint256 amountB, address poolAddress
    );

    event LogSwapTokenToToken(
        address _sender,
        address _tokenIn,
        address _tokenOut,
        address _poolAddress,
        uint256 _fees,
        uint256 _amountIn,
        uint256 _amountOut
    );

    constructor(address _factory, address _weth, address initialOwner) Ownable(initialOwner) {
        require(_weth != address(0), "not valid weth address!");
        factory = IPoolFactory(_factory);
        WETH = _weth;
    }

    function setNewOwnerFees(uint256 _ownerFees) external onlyOwner {
        // 100 represents 1%
        ownerFees = _ownerFees;
    }

    function setNewPoolFactory(address _factory) external onlyOwner {
        require(_factory != address(0), "zero address not allowed!");
        factory = IPoolFactory(_factory);
    }

    function _swapTokenToToken(address _poolAddress, address _to, address _tokenIn, uint256 _amountIn) internal {
        uint256 amountOut;

        amountOut = ILiquidityPool(_poolAddress).getAmountOut(_tokenIn, _amountIn);
        ILiquidityPool(_poolAddress).swapTokens(amountOut, _to, _tokenIn);
    }

    function swapTokenToToken(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _minAmountOut)
        external
        nonReentrant
    {
        address to = msg.sender;
        require(_tokenIn != _tokenOut, "tokens should be different!");
        require(_tokenIn != address(0) && _tokenOut != address(0), "tokens should not be zero!");
        require(_amountIn > 0, "amount in should not be zero");

        address poolAddress = getPoolAddress(_tokenIn, _tokenOut);

        uint256 amountIn = transferTokens(_amountIn, _tokenIn, to, poolAddress);

        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(to);

        _swapTokenToToken(poolAddress, to, _tokenIn, amountIn);

        uint256 balanceAfter = IERC20(_tokenOut).balanceOf(to);
        uint256 amountOut = balanceAfter - balanceBefore;
        require(amountOut >= _minAmountOut, "insufficient output amount");

        uint256 _fees = ILiquidityPool(poolAddress).fees();
        emit LogSwapTokenToToken(msg.sender, _tokenIn, _tokenOut, poolAddress, _fees, _amountIn, amountOut);
    }

    function transferTokens(uint256 _amountIn, address _tokenIn, address _to, address _poolAddress)
        internal
        returns (uint256 amountIn)
    {
        uint256 _ownerFees;

        (_ownerFees, amountIn) = getAmountIn(_amountIn);

        IERC20(_tokenIn).safeTransferFrom(_to, owner(), _ownerFees);
        IERC20(_tokenIn).safeTransferFrom(_to, _poolAddress, amountIn);
    }

    function getAmountIn(uint256 _amountIn) public view returns (uint256 _ownerFees, uint256 amountIn) {
        _ownerFees = (_amountIn * ownerFees) / factor;
        amountIn = _amountIn - _ownerFees;
    }

    function swapETHForTokens(address _tokenOut, uint256 _minAmountOut) external payable nonReentrant {
        address to = msg.sender;
        require(_tokenOut != address(0), "Zero address not allowed!");

        (, uint256 amountIn) = getAmountIn(msg.value);

        IWETH(WETH).deposit{value: amountIn}();

        address poolAddress = getPoolAddress(WETH, _tokenOut);

        require(IWETH(WETH).transfer(poolAddress, amountIn), "weth transfer failed!");

        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(to);

        _swapTokenToToken(poolAddress, to, WETH, amountIn);

        uint256 balanceAfter = IERC20(_tokenOut).balanceOf(to);

        uint256 amountOut = balanceAfter - balanceBefore;

        require(amountOut >= _minAmountOut, "insufficient output amount");

        emit LogSwapETHForTokens(msg.sender, msg.value, _tokenOut, poolAddress);
    }

    function swapTokensForETH(address _tokenIn, uint256 _amountIn, uint256 _minAmountOut) external nonReentrant {
        address to = msg.sender;
        require(_tokenIn != address(0), "Zero address not allowed!");

        address poolAddress = getPoolAddress(_tokenIn, WETH);

        uint256 amountIn = transferTokens(_amountIn, _tokenIn, to, poolAddress);

        _swapTokenToToken(poolAddress, address(this), _tokenIn, amountIn);

        uint256 amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut > 0, "amountOut is zero!");
        require(amountOut >= _minAmountOut, "insufficient output amount");

        IWETH(WETH).withdraw(amountOut);

        (bool success,) = to.call{value: amountOut}("");
        require(success, "ETH transfer failed!");

        emit LogSwapTokensForETH(msg.sender, amountIn, _tokenIn, poolAddress);
    }

    function addTokenToTokenLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(_tokenA != _tokenB, "tokens should be different!");
        require(_tokenA != address(0) && _tokenB != address(0), "token address should not be zero!");
        require(_amountADesired > 0, "TokenA amount is zero!");
        require(_amountBDesired > 0, "TokenB amount is zero!");

        address poolAddress = getPoolAddress(_tokenA, _tokenB);
        require(poolAddress != address(0), "Token pool does not exist!");

        (amountA, amountB) =
            _getOptimalLiquidityAmount(_tokenA, _tokenB, _amountADesired, _amountBDesired, _amountAMin, _amountBMin);

        IERC20(_tokenA).safeTransferFrom(msg.sender, poolAddress, amountA);
        IERC20(_tokenB).safeTransferFrom(msg.sender, poolAddress, amountB);

        liquidity = ILiquidityPool(poolAddress).addLiquidity(msg.sender);

        emit LogAddTokenToTokenLiquidity(msg.sender, _tokenA, _tokenB, amountA, amountB, poolAddress);
    }

    function addLiquidityETH(
        address _token,
        uint256 _amountTokenDesired,
        uint256 _amountTokenMin,
        uint256 _amountETHMin
    ) external payable nonReentrant returns (uint256 amountToken, uint256 amountETH, uint256 shares) {
        require(_amountTokenDesired > 0, "amount desired not equal to zero!");
        require(_token != address(0), "token address should not be zero!");
        require(msg.value > 0, "ether amount not equal to zero!");
        address to = msg.sender;
        address poolAddress = getPoolAddress(_token, WETH);
        require(poolAddress != address(0), "Token pool does not exist!");

        (amountToken, amountETH) =
            _getOptimalLiquidityAmount(_token, WETH, _amountTokenDesired, msg.value, _amountTokenMin, _amountETHMin);

        IERC20(_token).safeTransferFrom(to, poolAddress, amountToken);
        IWETH(WETH).deposit{value: amountETH}();

        require(IWETH(WETH).transfer(poolAddress, amountETH), "weth transfer failed!");

        shares = ILiquidityPool(poolAddress).addLiquidity(msg.sender);

        if (msg.value > amountETH) {
            (bool status,) = to.call{value: msg.value - amountETH}("");
            require(status, "transfer failed!");
        }

        emit LogAddLiquidityETH(msg.sender, _token, amountToken, poolAddress, shares);
    }

    function _getOptimalLiquidityAmount(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        address poolAddress = getPoolAddress(_tokenA, _tokenB);
        (,, uint256 reserveA, uint256 reserveB) = ILiquidityPool(poolAddress).getReserves(_tokenA);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint256 amountBOptimal = getTokenPoolRatio(_tokenA, _tokenB, _amountADesired);

            if (amountBOptimal <= _amountBDesired) {
                require(amountBOptimal >= _amountBMin, "Insufficient TokenB amount!");
                (amountA, amountB) = (_amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = getTokenPoolRatio(_tokenA, _tokenB, _amountBDesired);
                assert(amountAOptimal <= _amountADesired);
                require(amountAOptimal >= _amountAMin, "Insufficient TokenB amount!");
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }

    // **** Remove Liquidity ****
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _shares,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to
    ) public returns (uint256 amountA, uint256 amountB) {
        address poolAddress = getPoolAddress(_tokenA, _tokenB);
        require(poolAddress != address(0), "Token pool does not exist!");

        bool status = ILiquidityPool(poolAddress).transferFrom(msg.sender, poolAddress, _shares);
        require(status, "transfer failed!");

        (uint256 amount0, uint256 amount1) = ILiquidityPool(poolAddress).removeLiquidity(_to);

        (address token0, address token1) = sortTokens(_tokenA, _tokenB);

        (amountA, amountB) = _tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= _amountAMin, "TokenA amount not enough!");
        require(amountB >= _amountBMin, "TokenB amount not enough!");

        emit LogRemoveLiquidity(msg.sender, token0, token1, _shares, amountA, amountB, poolAddress);
    }

    function removeLiquidityETH(
        address _token,
        uint256 _shares,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        address _to
    ) external nonReentrant returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(_token, WETH, _shares, _amountTokenMin, _amountETHMin, address(this));
        require(IERC20(_token).transfer(_to, amountToken), "transfer failed!");

        IWETH(WETH).withdraw(amountETH);

        (bool status,) = _to.call{value: amountETH}("");
        require(status, "transfer failed!");

        emit LogRemoveLiquidityETH(msg.sender, _token, _shares, amountToken, amountETH);
    }

    function getTokenPoolRatio(address _tokenA, address _tokenB, uint256 _amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        address poolAddress = getPoolAddress(_tokenA, _tokenB);
        (,, uint256 reserveIn, uint256 reserveOut) = ILiquidityPool(poolAddress).getReserves(_tokenA);

        amountOut = reserveIn == 0 ? 0 : (reserveOut * _amountIn) / reserveIn;
    }

    function getTokenPoolReserves(address _token0, address _token1)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        address poolAddress = getPoolAddress(_token0, _token1);
        require(poolAddress != address(0), "pool does not exist!");

        (amount0, amount1,) = ILiquidityPool(poolAddress).getLatestReserves();
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "tokens should be different!");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "zero address not allowed!");
    }

    function getPoolAmountOut(address _tokenIn, address _tokenOut, uint256 _amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        address poolAddress = getPoolAddress(_tokenIn, _tokenOut);
        require(poolAddress != address(0), "pool does not exist!");

        uint256 amountIn;
        (, amountIn) = getAmountIn(_amountIn);

        amountOut = ILiquidityPool(poolAddress).getAmountOut(_tokenIn, amountIn);
    }

    function getPoolAddress(address _token0, address _token1) internal view returns (address poolAddress) {
        (address token0, address token1) = sortTokens(_token0, _token1);
        poolAddress = IPoolFactory(factory).getPoolAddress(token0, token1);
        require(poolAddress != address(0), "pool does not exist!");
    }

    function withdrawEtherFees() external onlyOwner {
        (bool status,) = msg.sender.call{value: address(this).balance}("");
        require(status, "transfer failed!");
    }

    receive() external payable {
        require(msg.sender == WETH);
    }
}
