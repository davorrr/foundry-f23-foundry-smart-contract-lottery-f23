// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {

    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 entranceFee; 
        uint256 interval;
        address vrfCoordinator; 
        bytes32 gasLane;
        uint64 subscriptionId; 
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
            console.log("Sepolia deployer key is: ", activeNetworkConfig.deployerKey);
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
            console.log("Anvil deployer key is: ", activeNetworkConfig.deployerKey);
        }
    }

    // Now we can pretend we will deploy this contract to Sepolia
    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // Update with our subId
            callbackGasLimit: 500000, // 500,00 gas!
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // Link contract address
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    // If we want to test the contract locally we need an Anvil config with mocks:
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // We check the address. If it's not 0 we can assume vrfcoor has been populated
        if (activeNetworkConfig.vrfCoordinator != address(0)) { 
            return activeNetworkConfig;
        }

        // We need to create a set of mock contracts we will be working with locally
        uint96 baseFee = 0.25 ether; // 0.25 LINK
        uint96 gasPriceLink = 1e9;   // 1 gwei LINK
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // Our script adds this
            callbackGasLimit: 500000, // 500,00 gas!
            link: address(link),  // In difference with Sepolia, with Anvil we have to deploy a mock link token
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
}