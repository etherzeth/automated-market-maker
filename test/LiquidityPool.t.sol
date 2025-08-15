// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";
import "../src/utils/Token.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityPoolFoundryTest is Test {
    LiquidityPool pool;
    Token dai;
    Token uni;

    address owner;
    address supplier1;
    address trader1;
    address notOwner;

    uint256 constant FEES = 2000;        // 2%
    uint256 constant INITIAL_TOKENS = 100 ether;
    uint256 constant TEN = 10 ether;
    uint256 constant FIVE = 5 ether;
    uint256 constant ONE = 1 ether;

    function setUp() public {
        // setup accounts
        owner = address(this);
        supplier1 = vm.addr(1);
        trader1   = vm.addr(2);
        notOwner  = vm.addr(3);

        // deploy tokens
        dai = new Token("DAI Token", "DAI", owner);
        uni = new Token("UNI Token", "UNI", owner);

        // deploy liquidity pool (constructor init pool)
        pool = new LiquidityPool(owner, address(dai), address(uni), FEES);

        // distribute tokens
        dai.transfer(supplier1, INITIAL_TOKENS);
        uni.transfer(supplier1, INITIAL_TOKENS);
        dai.transfer(trader1, INITIAL_TOKENS);
        uni.transfer(trader1, INITIAL_TOKENS);

        // approve pool
        vm.prank(supplier1);
        dai.approve(address(pool), INITIAL_TOKENS);
        vm.prank(supplier1);
        uni.approve(address(pool), INITIAL_TOKENS);

        vm.prank(trader1);
        dai.approve(address(pool), INITIAL_TOKENS);
        vm.prank(trader1);
        uni.approve(address(pool), INITIAL_TOKENS);

        // add initial liquidity
        vm.prank(supplier1);
        dai.transfer(address(pool), FIVE);
        vm.prank(supplier1);
        uni.transfer(address(pool), TEN);
    }

    // -------------------- TESTS --------------------

    function testOwnerIsCorrect() public {
        assertEq(pool.owner(), owner);
    }

    function testCannotInitZeroAddress() public {
        vm.expectRevert(bytes("already initialized"));
        pool.initPool(address(0), address(dai), FEES);
    }

    function testOnlyOwnerSetFees() public {
        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );
        pool.setPoolFees(500);
    }

    function testSetFeesByOwner() public {
        uint newFees = 1000;
        pool.setPoolFees(newFees);
        assertEq(pool.fees(), newFees);
    }

    function testAddLiquidity() public {
        vm.prank(supplier1);
        uint shares = pool.addLiquidity(supplier1);
        assertGt(shares, 0);
    }

    function testSwapTokens() public {
        vm.prank(supplier1);
        pool.addLiquidity(supplier1);

        uint traderUniBefore = uni.balanceOf(trader1);
        uint traderDaiBefore = dai.balanceOf(trader1);

        uint amountIn = ONE;

        vm.prank(trader1);
        uni.transfer(address(pool), amountIn);

        vm.prank(trader1);
        pool.swapTokens(pool.getAmountOut(address(uni), amountIn), trader1, address(uni));

        uint traderUniAfter = uni.balanceOf(trader1);
        uint traderDaiAfter = dai.balanceOf(trader1);

        assertApproxEqRel(traderUniAfter, traderUniBefore - amountIn, 1e16);
        assertGt(traderDaiAfter, traderDaiBefore);
    }


    function testRemoveLiquidity() public {
        vm.prank(supplier1);
        pool.addLiquidity(supplier1);

        uint shares = pool.balanceOf(supplier1);

        vm.prank(supplier1);
        pool.approve(supplier1, shares);

        vm.prank(supplier1);
        pool.transferFrom(supplier1, address(pool), shares);

        vm.prank(supplier1);
        pool.removeLiquidity(supplier1);

        assertEq(pool.balanceOf(supplier1), 0);
        assertEq(pool.totalSupply(), 0);
    }
}
