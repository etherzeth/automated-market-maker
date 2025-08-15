// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/utils/WETH.sol";
import "../src/PoolFactory.sol";
import "../src/PoolRouter.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy tokens
        Token dai = new Token("DAI Token", "DAI", 1_000_000 ether);
        Token twiz = new Token("TWIZ Token", "TWZ", 1_000_000 ether);
        Token dwi = new Token("DWI Token", "DWI", 1_000_000 ether);

        // Deploy WETH
        WETH9 weth = new WETH9();

        // Deploy PoolFactory (owner = deployer automatically)
        PoolFactory factory = new PoolFactory();

        // Deploy PoolRouter
        PoolRouter router = new PoolRouter(address(factory), address(weth), address(dai));

        // Log addresses
        console.log("const daiAddress =", address(dai));
        console.log("const twizAddress =", address(twiz));
        console.log("const dwiAddress =", address(dwi));
        console.log("const wethAddress =", address(weth));
        console.log("const factoryAddress =", address(factory));
        console.log("const routerAddress =", address(router));

        vm.stopBroadcast();
    }
}
