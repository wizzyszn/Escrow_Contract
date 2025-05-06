// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Escrow
 * @dev A simple escrow contract for holding funds between two parties
 */
contract Escrow is ReentrancyGuard {
    bytes32 public constant PLAYER_ROLE = keccak256("player");
    bytes32 public constant CHALLENGER_ROLE = keccak256("challenger");

    struct Storage {
        uint128 totalAmount; // Use uint128 to pack with other fields
        address player;
        address challenger;
        bool isActive;
    }

    mapping(bytes32 => Storage) public escrowStorage;

    // Events
    /**
     * @notice Emitted when a deposit is made to an escrow
     * @param storeHash The unique hash identifying the escrow
     * @param depositor The address of the depositor
     * @param identity The role of the depositor (PLAYER_ROLE or CHALLENGER_ROLE)
     * @param amount The amount of Ether deposited
     */
    event TokensStored(bytes32 indexed storeHash, address indexed depositor, bytes32 identity, uint amount);

    /**
     * @notice Emitted when funds are released from an escrow
     * @param storeHash The unique hash identifying the escrow
     * @param amount The amount of Ether released
     * @param winner The address receiving the funds
     */
    event ReleasedFunds(bytes32 indexed storeHash, uint indexed amount, address indexed winner);

    /**
     * @notice Store tokens in the escrow
     * @param storeHash The unique identifier for this escrow
     * @param identity The role of the depositor (PLAYER_ROLE or CHALLENGER_ROLE)
     */
    function storeTokens(bytes32 storeHash, bytes32 identity) external payable {
        // Checks
        require(msg.value > 0, "Invalid deposit");
        require(identity == PLAYER_ROLE || identity == CHALLENGER_ROLE, "Invalid identity");
        require(msg.value <= type(uint128).max, "Amount too large"); // Prevent overflow

        Storage storage escrow = escrowStorage[storeHash];

        // For new or existing escrows, validate participant slots
        if (identity == PLAYER_ROLE) {
            require(escrow.player == address(0), "Player already set");
            escrow.player = msg.sender;
        } else {
            require(escrow.challenger == address(0), "Challenger already set");
            escrow.challenger = msg.sender;
        }

        // Update state efficiently
        unchecked {
            escrow.totalAmount += uint128(msg.value); // Safe due to prior check
        }
        escrow.isActive = true;

        // Emit event
        emit TokensStored(storeHash, msg.sender, identity, msg.value);
    }

    /**
     * @notice Release funds to the winner
     * @param storeHash The unique identifier for this escrow
     * @param winner The address that should receive the funds
     */
    function releaseFunds(bytes32 storeHash, address winner) external nonReentrant {
        Storage storage escrow = escrowStorage[storeHash];

        // Checks
        require(escrow.isActive, "Escrow is not active");
        require(escrow.player == winner || escrow.challenger == winner, "Invalid winner");
        require(escrow.totalAmount > 0, "No funds to release");

        // Effects
        uint amount = escrow.totalAmount;
        escrow.totalAmount = 0;
        escrow.isActive = false;

        // Emit event before external call
        emit ReleasedFunds(storeHash, amount, winner);

        // Interactions: Use call instead of transfer for safer ETH sending
        (bool success, ) = winner.call{value: amount}("");
        require(success, "Transfer failed");
    }
}