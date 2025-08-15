// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/PoolRouter.sol";
import "../src/PoolFactory.sol";
import "../src/LiquidityPool.sol";
import "../src/utils/WETH.sol";
import "../src/utils/Token.sol";

contract TestPoolRouter is Test {
    PoolRouter public router;
    PoolFactory public factory;
    LiquidityPool public pool;
    Token public uni;
    Token public dai;
    WETH9 public weth;

    address owner;
    address supplier1;
    address supplier2;
    address trader1;
    address trader2;

    uint256 constant ZERO = 0;
    uint256 constant ONE = 1e18;
    uint256 constant FIVE = 5e18;
    uint256 constant TEN = 10e18;
    uint256 constant FEES = 2000;

    function setUp() public {
        owner = address(this);
        supplier1 = address(0x1);
        supplier2 = address(0x2);
        trader1 = address(0x3);
        trader2 = address(0x4);

        uni = new Token("Uniswap Token", "UNI", address(this));
        dai = new Token("DAI Token", "DAI", address(this));

        weth = new WETH9();

        factory = new PoolFactory();
        router = new PoolRouter(address(factory), address(weth), owner);

        // distribute tokens
        uni.transfer(supplier1, TEN);
        uni.transfer(supplier2, TEN);
        uni.transfer(trader1, TEN);
        uni.transfer(trader2, TEN);

        dai.transfer(supplier1, TEN);
        dai.transfer(supplier2, TEN);
        dai.transfer(trader1, TEN);
        dai.transfer(trader2, TEN);

        // approve router
        approveRouter(supplier1);
        approveRouter(supplier2);
        approveRouter(trader1);
        approveRouter(trader2);
    }

    function deployPool() internal returns (LiquidityPool) {
        factory.createPool(address(uni), address(dai), FEES);
        address poolAddr = factory.getPoolAddress(address(uni), address(dai));
        return LiquidityPool(poolAddr);
    }

    function addLiquidity(address _supplier, uint256 amountA, uint256 amountB) internal {
        vm.startPrank(_supplier);
        router.addTokenToTokenLiquidity(address(uni), address(dai), amountA, amountB, ZERO, ZERO);
        vm.stopPrank();
    }

    function approveRouter(address user) internal {
        vm.startPrank(user);
        uni.approve(address(router), type(uint256).max);
        dai.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        pool = deployPool();
        addLiquidity(supplier1, FIVE, TEN);

        (uint256 reserve0, uint256 reserve1,) = pool.getLatestReserves();
        assertEq(reserve0, FIVE);
        assertEq(reserve1, TEN);
    }

    function testSwapTokens() public {
        pool = deployPool();
        addLiquidity(supplier1, FIVE, TEN);

        vm.startPrank(trader1);
        uint256 amountOut = router.getPoolAmountOut(address(uni), address(dai), ONE);
        router.swapTokenToToken(address(uni), address(dai), ONE, ZERO);
        uint256 daiBal = dai.balanceOf(trader1);
        vm.stopPrank();

        assertApproxEqAbs(daiBal, amountOut, 1e19);
    }

    function testSwapETHForToken() public {
        factory.createPool(address(weth), address(dai), FEES);

        vm.deal(supplier1, TEN);
        vm.startPrank(supplier1);
        router.addLiquidityETH{value: TEN}(address(dai), FIVE, ZERO, ZERO);
        vm.stopPrank();

        vm.deal(trader1, ONE);
        vm.startPrank(trader1);
        uint256 balanceBefore = dai.balanceOf(trader1);
        router.swapETHForTokens{value: ONE}(address(dai), ZERO);
        uint256 balanceAfter = dai.balanceOf(trader1);
        vm.stopPrank();

        assertApproxEqAbs(balanceAfter - balanceBefore, router.getPoolAmountOut(address(weth), address(dai), ONE), 1e17);
    }

    function testSwapTokenForETH() public {
        factory.createPool(address(weth), address(dai), FEES);

        vm.deal(supplier1, TEN);
        vm.startPrank(supplier1);
        router.addLiquidityETH{value: TEN}(address(dai), FIVE, ZERO, ZERO);
        vm.stopPrank();

        approveRouter(trader1);

        vm.startPrank(trader1);
        uint256 amountOut = router.getPoolAmountOut(address(dai), address(weth), FIVE);
        router.swapTokensForETH(address(dai), FIVE, amountOut);
        vm.stopPrank();

        assertApproxEqAbs(trader1.balance, amountOut, 1e12);
    }
}
