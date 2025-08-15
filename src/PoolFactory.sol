// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {OnChainWhitelist} from "./utils/OnChainWhitelist.sol";
import {LiquidityPool} from "./LiquidityPool.sol";

contract PoolFactory is Pausable, OnChainWhitelist {
    address[] public allPools;
    mapping(address => mapping(address => address)) public getPoolAddress;

    event LogCreatePool(address indexed token0, address indexed token1, address sender, uint pairsLength);

    constructor() OnChainWhitelist(msg.sender) {
        whitelist[msg.sender] = true;
    }

    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }

    function createPool(address token0, address token1, uint fees)
        external
        whenNotPaused
        returns (address poolAddress)
    {
        require(whitelist[msg.sender] || msg.sender == owner(), "not authorized!");
        require(token0 != token1, "identical addresses not allowed!");
        require(token0 != address(0) && token1 != address(0), "zero address not allowed!");
        require(getPoolAddress[token0][token1] == address(0), "token pair exists!");
        require(fees <= 2000, "fees exceed max");

        // encode constructor args
        bytes memory bytecode = type(LiquidityPool).creationCode;
        bytes memory constructorArgs = abi.encode(msg.sender, token0, token1, fees); // owner langsung = msg.sender
        bytes memory finalBytecode = abi.encodePacked(bytecode, constructorArgs);

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            poolAddress := create2(0, add(finalBytecode, 0x20), mload(finalBytecode), salt)
        }

        require(poolAddress != address(0), "contract deployment failed!");

        getPoolAddress[token0][token1] = poolAddress;
        getPoolAddress[token1][token0] = poolAddress;
        allPools.push(poolAddress);

        emit LogCreatePool(token0, token1, msg.sender, allPools.length);
    }

    function poolExists(address tokenA, address tokenB) external view returns (bool exists) {
        exists = getPoolAddress[tokenA][tokenB] != address(0);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
