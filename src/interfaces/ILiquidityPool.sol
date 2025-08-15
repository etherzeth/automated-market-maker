// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILiquidityPool {
    function owner() external view returns (address);
    function fees() external view returns (uint256);
    function addLiquidity(address _to) external returns (uint256 shares);
    function swapTokens(uint256 _amountOut, address _to, address _tokenIn) external;
    function removeLiquidity(address _to) external returns (uint256 amount0, uint256 amount1);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function getTokenPairRatio(address _tokenIn, uint256 _amountIn) external view returns (uint256 tokenOut);
    function getAmountOut(address _tokenIn, uint256 _amountIn) external view returns (uint256 amountOut);
    function getLatestReserves()
        external
        view
        returns (uint256 _reserve0, uint256 reserve1, uint256 _blockTimestampLast);
    function getReserves(address _tokenIn)
        external
        view
        returns (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut);
}
