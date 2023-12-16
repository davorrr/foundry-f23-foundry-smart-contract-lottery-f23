// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, ,address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription ID is: ", subscriptionId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subscriptionId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function addConsumer(
        address raffle, 
        address vrfCoordinator, 
        uint64 subscriptionId, 
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (, ,address vrfCoordinator, , uint64 subscriptionId, , , uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (, ,address vrfCoordinator, , uint64 subscriptionId, ,address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subscriptionId, address link, uint256 deployerKey) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            // We are on local chain - Anvil
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // If we are not on the local chain, but on Sepolia testnet we will do the real 
            // transfer
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
 
    function run() external {
        fundSubscriptionUsingConfig();
    }
}



    
    