// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MonerioVault } from "../src/MonerioVault.sol";

contract DeployVault is Script {
    function run() external returns (address proxy, address implementation) {
        // Get token address from environment variable
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        require(tokenAddress != address(0), "TOKEN_ADDRESS not set");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        MonerioVault vaultImpl = new MonerioVault();
        console.log("Implementation deployed at:", address(vaultImpl));

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(MonerioVault.initialize.selector, tokenAddress);
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), initData);
        console.log("Proxy deployed at:", address(vaultProxy));

        MonerioVault vault = MonerioVault(address(vaultProxy));
        console.log("Vault owner:", vault.owner());
        console.log("Vault token:", address(vault.token()));

        vm.stopBroadcast();

        return (address(vaultProxy), address(vaultImpl));
    }
}

contract DeployVaultLocal is Script {
    function run() external returns (address proxy, address implementation, address mockToken) {
        vm.startBroadcast();

        // Deploy mock token for local testing
        MockJPYC token = new MockJPYC();
        console.log("Mock JPYC deployed at:", address(token));

        // Deploy implementation
        MonerioVault vaultImpl = new MonerioVault();
        console.log("Implementation deployed at:", address(vaultImpl));

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(MonerioVault.initialize.selector, address(token));
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), initData);
        console.log("Proxy deployed at:", address(vaultProxy));

        MonerioVault vault = MonerioVault(address(vaultProxy));
        console.log("Vault owner:", vault.owner());

        vm.stopBroadcast();

        return (address(vaultProxy), address(vaultImpl), address(token));
    }
}

// Simple mock for local deployment
contract MockJPYC {
    string public name = "JPY Coin";
    string public symbol = "JPYC";
    uint8 public decimals = 6;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
