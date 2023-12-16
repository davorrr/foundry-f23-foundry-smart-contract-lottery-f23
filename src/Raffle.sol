// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author Davor Yurich
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 { 

    /** Errors */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
    /** Type Declarations */
    enum RaffleState {
        OPEN,       // 0
        CALCULATING // 1
    }

    /** State variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    
    uint256 private immutable i_entranceFee;
    // @dev Duration of lottery in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    
    address payable[] private s_players; // Since the number keeps changing this is a storage variable
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint64 subscriptionId, 
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_gasLane = gasLane;

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;

    }

    function enterRaffle() external payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }
    /**
     * @dev This is the function that the Chainlink Automation nodes call to if it's time
     * to perform upkeep. The following should be true for this to return true:
     * 1. Time interval has passed between Raffle runs
     * 2. The raffle is in OPEN state
     * 3. The contract has ETH (aka. players)
     * 4. (Implicit) The subscription is funded with LINK
     * The return from the function will notify Chainlink Automation nodes that they should
     * perform upkeep. The function itself will evaluate a set of contract state variables.
     */
    function checkUpkeep (
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; 
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return(upkeepNeeded, "0x0");
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* peformData */) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState));
        }

        // There are 2 transactions:
        // 1. Request the RNG
        // 2. Get the random number

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords( // VRF coordinator address
            i_gasLane, // gas lane
            i_subscriptionId, // ID funded with link
            REQUEST_CONFIRMATIONS, // num of block confirmation for the number considered good
            i_callbackGasLimit, // Max gas we want callback function to spend
            NUM_WORDS // Number of Random Numbers we want
        );
        emit RequestedRaffleWinner(requestId); // Redundant because vrfCoordinatorMock emits an event that
                                                // returns requestId
    }

    /** Callback function that will be called by VRFConsumerBaseV2 */
    // CEI (Checks, Effects, Interactions) is followed 
    function fulfillRandomWords(uint256 /* */, uint256[] memory randomWords) internal override {
        // Checks (if -> errors)
        // Checks should be done first because in case of a revert, we will pay the least gas
        // since no addional computation was done compared to the situation where we would do
        // checks later in the code.

        // Effects (on our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        
        // We need to reset the players array once the winner is chosen
        s_players = new address payable[](0);
        // Timestamp also needs to be updated
        s_lastTimeStamp = block.timestamp;
        
        // Interactions (with other contracts) - this is done to prevent reentrancy attacks
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit PickedWinner(winner);
    }

    /** Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address){
       return s_players[indexOfPlayer]; 
    } 

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}