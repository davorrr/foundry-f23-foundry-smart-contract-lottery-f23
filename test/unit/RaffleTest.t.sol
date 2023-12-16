// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol"; // We import this so to test the deployement as well
import {Vm} from "forge-std/Test.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
//import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator; 
    bytes32 gasLane;
    uint64 subscriptionId; 
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;


    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run(); 
        (    
            entranceFee,
            interval,
            vrfCoordinator, 
            gasLane,
            subscriptionId, 
            callbackGasLimit,
            link,
        ) = helperConfig.activeNetworkConfig();
        (,,,,,,, deployerKey) = helperConfig.activeNetworkConfig();

        // We need to give our PLAYER some money to simulate the real life environment we are
        // testing against
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////////////////////
    // enterRaffle                  //
    //////////////////////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act & Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        // Arrange - We set the raffle to calculating
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Assert & Act - we try to enter the Raffle
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////////////////////////
    // checkUpkeep                     //
    /////////////////////////////////////
    /** Test checks if the function works correctly in case there is no balance but all other
     * parameters are TRUE
    */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1); // Ensuring enough time has passed
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER); 
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // Setting raffle in the calculating state

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }
    // testCheckUpkeepReturnsTrueWhenParametersAreGood
    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER); 
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /////////////////////
    // performUpkeep   //
    /////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance  = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // Act / Assert
        // Below we expect that the perfrom upkeep reverts with an expected error code and correct parameters
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if I need to test using the output of an event?
    function testPerformUpkeepUpdatesRaffleStateAndEmitRequestId() public raffleEnteredAndTimePassed {
        // Arrange
        /**Below code replaced by a modifier */
        // vm.prank(PLAYER);
        // raffle.enterRaffle{value: entranceFee}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // This means that our requestId will be
                                                  // in the second entry, second position. The
                                                  // first position (topic) refers the the 
                                                  // entire event
        Raffle.RaffleState rState = raffle.getRaffleState();
        
        assert(uint256(requestId) > 0);
        assert(rState == Raffle.RaffleState.CALCULATING);
    }

    ////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");

        // To test for a single requestId we would write a line like the one below:
        // VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));
        
        // To do thorough testing we would need to test with all possible requestIds - 0 .. n
        // To achieve this we do fuzz testing where we use randomRequestId parameter instead 
        // of hardcoding 0, 1, 2, ..., n
        // Now when we execute this test Foundry will create a random number and call the test
        // many times with many different random numbers to make sure that the nonexistant request
        // error reliably happens for all non existing requestsIDs
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFilfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork {
        // This is a full test: we will enter the lottery, move the time up so that checkUpkeep returns true
        // we will performUpkeep, we will initiate a request to get a random number, we will pretend 
        // to be chainlink VRF, we will respond and call fulfillRandomWords

        // Arrange
        uint256 additionalEntrance = 5; // since we went through the modifer raffleEnteredAndTimePassed we
                                        // already have one person in the raffle to which we add 5 more.
        uint256 startingIndex = 1;


        for (uint256 i = startingIndex; i < startingIndex + additionalEntrance; ++i) {
            address player = address(uint160(i)); // Generating a player address based on an index number
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}(); // now we are entering the raffle pretending to be the
                                                      // player that has some ETH associated with his account
        }

        uint256 prize = entranceFee * additionalEntrance;

        vm.recordLogs();
        raffle.performUpkeep(""); 
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimestamp = raffle.getLastTimestamp();

        // Pretend to be chainlink VRF to get a random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(raffle.getLastTimestamp() > previousTimestamp);
        console.log(raffle.getRecentWinner().balance);
        console.log(prize);
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize);
    }
}