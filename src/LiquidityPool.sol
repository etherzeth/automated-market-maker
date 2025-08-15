// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenPool} from "./utils/TokenPool.sol";
import {Math} from "./utils/Math.sol";

contract LiquidityPool is TokenPool, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public token0;
    IERC20 public token1;

    uint256 public constant MAX_FEE_AMOUNT = 2000; // 2%
    uint256 private constant FACTOR = 100000;
    uint256 private reserve0;
    uint256 private reserve1;
    uint256 public fees;
    uint256 private lastTimestamp;
    bool public initialized;

    modifier onlyPairTokens(address _tokenIn) {
        require(_tokenIn == address(token0) || _tokenIn == address(token1), "token not supported!");
        _;
    }

    event LogWithdrawIncorrectDeposit(address _tokenAddress, address _receiver);

    constructor(address initialOwner, address _token0, address _token1, uint256 _fees) TokenPool(initialOwner) {
        require(_token0 != address(0) && _token1 != address(0), "zero address not allowed!");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        require(_fees <= MAX_FEE_AMOUNT, "fees exceed limit!");
        fees = _fees;
        initialized = true;
    }

    function initPool(address _token0, address _token1, uint256 _fees) external onlyOwner {
        require(!initialized, "already initialized");
        require(_token0 != address(0) && _token1 != address(0), "zero address not allowed");
        require(_fees <= MAX_FEE_AMOUNT, "fees exceed limit");

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        fees = _fees;
        initialized = true;
    }

    function getLatestReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint256 _lastTimestamp) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _lastTimestamp = lastTimestamp;
    }

    function setPoolFees(uint256 _newFees) external onlyOwner {
        require(_newFees != fees, "fees should be different!");
        require(_newFees <= MAX_FEE_AMOUNT, "fees exceed limit!");
        fees = _newFees;
    }

    function _updateReserves(uint256 _reserve0, uint256 _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        lastTimestamp = block.timestamp;
    }

    function swapTokens(uint256 _amountOut, address _to, address _tokenIn) external whenNotPaused nonReentrant {
        require(_amountOut > 0, "amountOut should be > 0");

        (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = getReserves(_tokenIn);
        require(_amountOut < reserveOut, "not enough reserveOut");

        IERC20(tokenOut).safeTransfer(_to, _amountOut);

        uint256 balance0 = tokenIn.balanceOf(address(this));
        uint256 balance1 = tokenOut.balanceOf(address(this));

        (uint256 newReserve0, uint256 newReserve1) =
            _tokenIn == address(token0) ? (balance0, balance1) : (balance1, balance0);

        _updateReserves(newReserve0, newReserve1);

        require(newReserve0 * newReserve1 >= reserveIn * reserveOut, "swap failed");
    }

    function getReserves(address _tokenIn)
        public
        view
        returns (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut)
    {
        bool isToken0 = _tokenIn == address(token0);
        (tokenIn, tokenOut, reserveIn, reserveOut) =
            isToken0 ? (token0, token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);
    }

    function getAmountOut(address _tokenIn, uint256 _amountIn)
        external
        view
        onlyPairTokens(_tokenIn)
        returns (uint256 amountOut)
    {
        (,, uint256 reserveIn, uint256 reserveOut) = getReserves(_tokenIn);
        uint256 amountInWithFee = (_amountIn * (FACTOR - fees)) / FACTOR;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
    }

    function addLiquidity(address _to) external whenNotPaused returns (uint256 shares) {
        (uint256 _reserve0, uint256 _reserve1,) = getLatestReserves();

        uint256 _balance0 = token0.balanceOf(address(this));
        uint256 _balance1 = token1.balanceOf(address(this));

        uint256 _amount0 = _balance0 - _reserve0;
        uint256 _amount1 = _balance1 - _reserve1;

        require(_amount0 != 0 && _amount1 != 0, "liquidity = 0");

        uint256 _totalSupply = totalSupply();
        shares = _totalSupply == 0
            ? Math.sqrt(_amount0 * _amount1)
            : Math.min((_amount0 * _totalSupply) / _reserve0, (_amount1 * _totalSupply) / _reserve1);

        require(shares > 0, "shares = 0");
        _mint(_to, shares);

        _updateReserves(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    function removeLiquidity(address _to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        uint256 shares = balanceOf(address(this));
        uint256 _totalSupply = totalSupply();

        amount0 = (shares * balance0) / _totalSupply;
        amount1 = (shares * balance1) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "amount0/1 = 0");
        _burn(address(this), shares);

        _updateReserves(balance0 - amount0, balance1 - amount1);

        token0.safeTransfer(_to, amount0);
        token1.safeTransfer(_to, amount1);
    }

    function withdrawIncorrectDeposit(IERC20 _token, address _receiver) external onlyOwner nonReentrant {
        require(_token != token0 && _token != token1, "token in pool");
        uint256 balance = _token.balanceOf(address(this));
        _token.safeTransfer(_receiver, balance);
        emit LogWithdrawIncorrectDeposit(address(_token), _receiver);
    }

    function pause() external onlyOwner returns (bool) {
        _pause();
        return true;
    }

    function unpause() external onlyOwner returns (bool) {
        _unpause();
        return true;
    }
}
