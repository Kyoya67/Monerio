// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { MonerioVault } from "../src/MonerioVault.sol";

contract UpgradeVault is Script {
    function run() external returns (address newImplementation) {
        // Get existing proxy address
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        require(proxyAddress != address(0), "PROXY_ADDRESS not set");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        MonerioVault newImpl = new MonerioVault();
        console.log("New implementation deployed at:", address(newImpl));

        // Upgrade proxy to new implementation
        MonerioVault vault = MonerioVault(proxyAddress);
        vault.upgradeToAndCall(address(newImpl), "");
        console.log("Proxy upgraded successfully");

        vm.stopBroadcast();

        return address(newImpl);
    }
}
