// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract Escrow is ReentrancyGuard, Ownable {
    bytes32 public constant PLAYER_ROLE = keccak256("player");
    bytes32 public constant CHALLENGER_ROLE = keccak256("challenger");
    address public oracleAddress;
    struct Storage {
        bytes32 matchId;
        address player;
        address challenger;
        bytes32 choiceA;
        bytes32 choiceB;
        uint128 totalAmount;
        bool isActive;
        bool isResolved;
    }
    mapping(bytes32 => Storage) public escrowStorage;
    uint256 public betCounter;
    event TokensStored(bytes32 indexed storeHash, address indexed depositor, bytes32 identity, bytes32 matchId, bytes32 choice, uint amount);
    event BetAccepted(bytes32 indexed storeHash, address indexed acceptor, bytes32 choice);
    event ReleasedFunds(bytes32 indexed storeHash, uint indexed amount, address indexed winner);
    event DrawDeclared(bytes32 indexed storeHash);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    constructor(address _oracleAddress) Ownable(msg.sender) {
        require(_oracleAddress != address(0), "Invalid oracle address");
        oracleAddress = _oracleAddress;
        emit OracleUpdated(address(0), _oracleAddress);
    }
    modifier onlyOracle() {
        require(msg.sender == oracleAddress, "Caller is not the oracle");
        _;
    }
    function updateOracle(address _newOracleAddress) external onlyOwner {
        require(_newOracleAddress != address(0), "Invalid oracle address");
        address oldOracle = oracleAddress;
        oracleAddress = _newOracleAddress;
        emit OracleUpdated(oldOracle, _newOracleAddress);
    }
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
    function releaseFunds(bytes32 storeHash, address winner) external nonReentrant onlyOracle {
        Storage storage escrow = escrowStorage[storeHash];
        require(escrow.isActive, "Escrow is not active");
        require(!escrow.isResolved, "Bet already resolved");
        require(escrow.challenger != address(0), "Bet not accepted");
        require(escrow.totalAmount > 0, "No funds to release");
        require(winner == escrow.player || winner == escrow.challenger, "Invalid winner");
        escrow.isResolved = true;
        escrow.isActive = false;
        uint amount = escrow.totalAmount;
        escrow.totalAmount = 0;
        emit ReleasedFunds(storeHash, amount, winner);
        (bool success, ) = winner.call{value: amount}("");
        require(success, "Transfer failed");
    }
    function declareDraw(bytes32 storeHash) external nonReentrant onlyOracle {
        Storage storage escrow = escrowStorage[storeHash];
        require(escrow.isActive, "Escrow is not active");
        require(!escrow.isResolved, "Bet already resolved");
        require(escrow.challenger != address(0), "Bet not accepted");
        require(escrow.totalAmount > 0, "No funds to release");
        escrow.isResolved = true;
        escrow.isActive = false;
        uint total = escrow.totalAmount;
        uint playerAmount = total / 2;
        uint challengerAmount = total - playerAmount;
        escrow.totalAmount = 0;
        emit DrawDeclared(storeHash);
        (bool successPlayer, ) = escrow.player.call{value: playerAmount}("");
        (bool successChallenger, ) = escrow.challenger.call{value: challengerAmount}("");
        require(successPlayer && successChallenger, "Refund failed");
    }
    function getCurrentBalance(bytes32 storeHash) external view returns (uint) {
        Storage storage escrow = escrowStorage[storeHash];
        return uint128(escrow.totalAmount);
    }
}