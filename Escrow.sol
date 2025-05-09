// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Escrow
 * @dev An escrow contract for holding funds between two parties for betting on sports events
 */
contract Escrow is ReentrancyGuard {
    bytes32 public constant PLAYER_ROLE = keccak256("player");
    bytes32 public constant CHALLENGER_ROLE = keccak256("challenger");

    struct Storage {
        bytes32 matchId;           // Unique identifier for the match
        address player;            // Address of the player (proposer)
        address challenger;        // Address of the challenger (acceptor)
        bytes32 choiceA;           // Player's choice (e.g., team to win)
        bytes32 choiceB;           // Challenger's choice (e.g., opposing team)
        uint128 totalAmount;       // Total stake amount (packed with other fields)
        bool isActive;             // Whether the bet is active
        bool isResolved;           // Whether the bet has been resolved
    }

    mapping(bytes32 => Storage) public escrowStorage;
    uint256 public betCounter;     // Counter for generating unique bet IDs

    // Events
    event TokensStored(bytes32 indexed storeHash, address indexed depositor, bytes32 identity, bytes32 matchId, bytes32 choice, uint amount);
    event BetAccepted(bytes32 indexed storeHash, address indexed acceptor, bytes32 choice);
    event ReleasedFunds(bytes32 indexed storeHash, uint indexed amount, address indexed winner);
    event DrawDeclared(bytes32 indexed storeHash);

    /**
     * @notice Create a bet proposal
     * @param matchId The unique identifier for the match
     * @param choice The choice of the proposer (e.g., team to win)
     * @param acceptor The address of the intended acceptor
     */
    function storeTokens(bytes32 matchId, bytes32 choice, address acceptor) external payable {
        require(msg.value > 0, "Invalid deposit");
        require(msg.value <= type(uint128).max, "Amount too large");
        require(acceptor != address(0), "Invalid acceptor address");
        require(acceptor != msg.sender, "Cannot accept own bet");

        bytes32 storeHash = keccak256(abi.encodePacked(betCounter++, msg.sender));
        Storage storage escrow = escrowStorage[storeHash];

        escrow.matchId = matchId;
        escrow.player = msg.sender;
        escrow.choiceA = choice;
        escrow.totalAmount = uint128(msg.value);
        escrow.isActive = true;

        emit TokensStored(storeHash, msg.sender, PLAYER_ROLE, matchId, choice, msg.value);
    }

    /**
     * @notice Accept a bet proposal
     * @param storeHash The unique identifier for the bet
     * @param choice The choice of the acceptor (e.g., opposing team)
     */
    function acceptBet(bytes32 storeHash, bytes32 choice) external payable {
        Storage storage escrow = escrowStorage[storeHash];
        require(escrow.isActive, "Bet is not active");
        require(escrow.challenger == address(0), "Bet already accepted");
        require(msg.value == escrow.totalAmount, "Stake must match");
        require(choice != escrow.choiceA, "Choice must be opposite");

        escrow.challenger = msg.sender;
        escrow.choiceB = choice;
        escrow.totalAmount += uint128(msg.value); 

        emit BetAccepted(storeHash, msg.sender, choice);
    }

    /**
     * @notice Release funds to the winner
     * @param storeHash The unique identifier for this escrow
     * @param winner The address that should receive the funds
     */
    function releaseFunds(bytes32 storeHash, address winner) external nonReentrant {
        Storage storage escrow = escrowStorage[storeHash];
        require(escrow.isActive, "Escrow is not active");
        require(!escrow.isResolved, "Bet already resolved");
        require(escrow.challenger != address(0), "Bet not accepted");
        require(escrow.totalAmount > 0, "No funds to release");
        require(winner == escrow.player || winner == escrow.challenger, "Invalid winner");

        // Effects
        escrow.isResolved = true;
        escrow.isActive = false;
        uint amount = escrow.totalAmount;
        escrow.totalAmount = 0;

        // Interactions
        emit ReleasedFunds(storeHash, amount, winner);
        (bool success, ) = winner.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Declare a draw and refund both parties
     * @param storeHash The unique identifier for this escrow
     */
    function declareDraw(bytes32 storeHash) external nonReentrant {
        Storage storage escrow = escrowStorage[storeHash];
        require(escrow.isActive, "Escrow is not active");
        require(!escrow.isResolved, "Bet already resolved");
        require(escrow.challenger != address(0), "Bet not accepted");
        require(escrow.totalAmount > 0, "No funds to release");

        // Effects
        escrow.isResolved = true;
        escrow.isActive = false;
        
        // Calculate fair split amounts, handling odd wei values
        uint total = escrow.totalAmount;
        uint playerAmount = total / 2;
        uint challengerAmount = total - playerAmount; 
        
        escrow.totalAmount = 0;

        // Interactions
        emit DrawDeclared(storeHash);
        (bool successPlayer, ) = escrow.player.call{value: playerAmount}("");
        (bool successChallenger, ) = escrow.challenger.call{value: challengerAmount}("");
        require(successPlayer && successChallenger, "Refund failed");
    }

    /**
     * @notice Get the current balance of a bet
     * @param storeHash The unique identifier for the bet
     * @return The total amount staked in the bet
     */
    function getCurrentBalance(bytes32 storeHash) external view returns (uint) {
        Storage storage escrow = escrowStorage[storeHash];
        return uint128(escrow.totalAmount);
    }
}