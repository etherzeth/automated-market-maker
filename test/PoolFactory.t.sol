// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PoolFactory.sol";
import "../src/utils/Token.sol";
import "../src/LiquidityPool.sol";

contract TestPoolFactory is Test {
    PoolFactory factory;
    Token dai;
    Token uni;

    address owner;
    address notOwner;

    uint256 constant FEES = 2000; // 2%

    function setUp() public {
        owner = address(this);
        notOwner = vm.addr(1);

        dai = new Token("DAI Token", "DAI", owner);
        uni = new Token("UNI Token", "UNI", owner);

        factory = new PoolFactory();
    }

    function testOwnerIsCorrect() public view {
        assertEq(factory.owner(), owner);
    }

    function testCreatePool() public {
        address poolAddr = factory.createPool(address(dai), address(uni), FEES);
        LiquidityPool pool = LiquidityPool(poolAddr);

        assertEq(address(pool.token0()), address(dai));
        assertEq(address(pool.token1()), address(uni));
        assertEq(pool.fees(), FEES);

        assertTrue(poolAddr != address(0));
    }

    function testCannotCreatePoolByNonOwner() public {
        vm.prank(notOwner);
        vm.expectRevert(bytes("not authorized!"));
        factory.createPool(address(dai), address(uni), FEES);
    }

    function testCannotCreatePoolWithZeroAddress() public {
        vm.expectRevert(bytes("zero address not allowed!"));
        factory.createPool(address(0), address(uni), FEES);

        vm.expectRevert(bytes("zero address not allowed!"));
        factory.createPool(address(dai), address(0), FEES);
    }
}
