// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPoolFactory {
    function owner() external view returns (address);
    function allPoolsLength() external view returns (uint256);
    function allPool(uint256) external view returns (address pair);
    function getPoolAddress(address tokenA, address tokenB) external view returns (address pair);
    function createPool(address tokenA, address tokenB, uint256 fees) external view returns (address pair);
}
