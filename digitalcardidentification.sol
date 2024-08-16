// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DigitalCardIdentification is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    // Data Structures
    struct User {
        address userAddress;
        bytes32 dataHash; // Hash of the user's personal data
        uint256 expirationDate; // Timestamp of expiration
        bool isValid; // Card validity status
    }

    // Mapping of user address to their digital card
    mapping(address => User) private users;

    // Unique identifier counter
    Counters.Counter private uniqueIdentifierCounter;

    // Events
    event CardIssued(address indexed userAddress, uint256 expirationDate);
    event CardRevoked(address indexed userAddress);
    event CardVerified(address indexed verifier, address indexed userAddress, bool isValid);

    // Modifiers
    modifier onlyValidCard(address _userAddress) {
        require(users[_userAddress].isValid, "Card is not valid");
        require(block.timestamp <= users[_userAddress].expirationDate, "Card has expired");
        _;
    }

    // Issue a new digital card
    function issueCard(address _userAddress, bytes32 _dataHash, uint256 _validityPeriodInSeconds) external onlyOwner nonReentrant {
        require(_userAddress != address(0), "Invalid address");
        require(_dataHash != bytes32(0), "Invalid data hash");

        uint256 expirationDate = block.timestamp + _validityPeriodInSeconds;

        users[_userAddress] = User({
            userAddress: _userAddress,
            dataHash: _dataHash,
            expirationDate: expirationDate,
            isValid: true
        });

        emit CardIssued(_userAddress, expirationDate);
    }

    // Revoke an existing card
    function revokeCard(address _userAddress) external onlyOwner nonReentrant onlyValidCard(_userAddress) {
        users[_userAddress].isValid = false;
        emit CardRevoked(_userAddress);
    }

    // Verify a digital card
    function verifyCard(address _userAddress, bytes32 _providedDataHash) external nonReentrant returns (bool) {
        User memory user = users[_userAddress];
        bool isValid = user.isValid && (user.dataHash == _providedDataHash) && (block.timestamp <= user.expirationDate);

        emit CardVerified(msg.sender, _userAddress, isValid);
        return isValid;
    }

    // Check if a user's card is valid
    function isCardValid(address _userAddress) external view returns (bool) {
        return users[_userAddress].isValid && (block.timestamp <= users[_userAddress].expirationDate);
    }

    // Reduce gas costs by allowing the deletion of expired or revoked cards
    function cleanupExpiredCard(address _userAddress) external onlyOwner nonReentrant {
        require(!users[_userAddress].isValid || block.timestamp > users[_userAddress].expirationDate, "Card is still valid");

        delete users[_userAddress];
    }

    // Reduce storage cost by avoiding unnecessary writes
    function isValidUser(address _userAddress) external view returns (bool) {
        return users[_userAddress].isValid;
    }

    // Withdraw contract funds
    function withdraw() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }
}
