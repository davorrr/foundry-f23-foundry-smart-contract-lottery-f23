// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

// The question is: why do we use run()
// The 2. question is: why do we return the contract object
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        // We first need to deploy a new helper config that will check our network and set the 
        // testing parameters accordingly:
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();

        // We will deconstruct the networkConfig object into underlying parameters
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator, 
            bytes32 gasLane,
            uint64 subscriptionId, 
            uint32 callbackGasLimit, 
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        // (,,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // We dont have a subscription ID set and we will need one!
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            // After we create a subscription we have to fund it. For this we will use Interactions script
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
            
        }
        console.log("deployer key is: ", deployerKey);
        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator, 
            gasLane,
            subscriptionId, 
            callbackGasLimit
        );
        vm.stopBroadcast();


        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId, deployerKey);
        return (raffle, helperConfig);
    }
}