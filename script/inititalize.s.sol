// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PoolFactory.sol";

contract Initialize is Script {
    address constant FACTORY = 0xe82e77f6a81E5B0cC791bca298AbAEf60ad83a88;
    address constant DAI = 0x831fdB691F7b874a2a229dEe974430b9cB0FC044;
    address constant TWIZ = 0x9C94dF046606595225958b0f17849F728b4D516C;
    address constant DWI = 0x5F754c88836e4D9961676cb5b74732265960309B;
    address constant WETH = 0xAbb972Fc416F7D3A8d7db748c5439238d051a099;

    uint256 constant FEES = 2000; // 2%

    function run() external {
        vm.startBroadcast();

        PoolFactory factory = PoolFactory(FACTORY);

        factory.createPool(DAI, WETH, FEES);
        factory.createPool(TWIZ, WETH, FEES);
        factory.createPool(DWI, WETH, FEES);

        vm.stopBroadcast();
    }
}
