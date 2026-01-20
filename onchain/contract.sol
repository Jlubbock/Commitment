// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CommitmentContract
 * @notice A binding commitment contract. Funds are released only if both parties
 *         sign before the deadline. After the deadline, funds are locked forever.
 * 
 * How it works:
 * 1. Depositor creates a commitment with ETH, a commitment hash, a partner address, and a deadline
 * 2. Before the deadline: BOTH depositor AND partner must sign to release funds back to depositor
 * 3. After the deadline: Funds are permanently locked. No one can touch them. Ever.
 */
contract CommitmentContract {
    
    struct Commitment {
        address depositor;
        address partner;
        uint256 amount;
        uint256 deadline;
        bytes32 commitmentHash;
        bool depositorSigned;
        bool partnerSigned;
        bool released;
    }
    
    mapping(uint256 => Commitment) public commitments;
    uint256 public nextCommitmentId;
    
    event CommitmentCreated(
        uint256 indexed commitmentId,
        address indexed depositor,
        address indexed partner,
        uint256 amount,
        uint256 deadline,
        bytes32 commitmentHash
    );
    
    event SignedForRelease(uint256 indexed commitmentId, address indexed signer);
    event FundsReleased(uint256 indexed commitmentId, address indexed depositor, uint256 amount);
    
    /**
     * @notice Create a new commitment
     * @param _partner Address of your accountability partner
     * @param _deadline Unix timestamp when the commitment expires
     * @param _commitmentHash keccak256 hash of your commitment text
     */
    function createCommitment(
        address _partner,
        uint256 _deadline,
        bytes32 _commitmentHash
    ) external payable returns (uint256 commitmentId) {
        require(msg.value > 0, "Must deposit ETH");
        require(_partner != address(0), "Invalid partner");
        require(_partner != msg.sender, "Partner cannot be self");
        require(_deadline > block.timestamp, "Deadline must be future");
        
        commitmentId = nextCommitmentId++;
        
        commitments[commitmentId] = Commitment({
            depositor: msg.sender,
            partner: _partner,
            amount: msg.value,
            deadline: _deadline,
            commitmentHash: _commitmentHash,
            depositorSigned: false,
            partnerSigned: false,
            released: false
        });
        
        emit CommitmentCreated(
            commitmentId, msg.sender, _partner, msg.value, _deadline, _commitmentHash
        );
    }
    
    /**
     * @notice Sign to release funds. Both parties must call this before deadline.
     */
    function signForRelease(uint256 _commitmentId) external {
        Commitment storage c = commitments[_commitmentId];
        
        require(!c.released, "Already released");
        require(block.timestamp < c.deadline, "Deadline passed");
        require(msg.sender == c.depositor || msg.sender == c.partner, "Not authorized");
        
        if (msg.sender == c.depositor) {
            require(!c.depositorSigned, "Already signed");
            c.depositorSigned = true;
        } else {
            require(!c.partnerSigned, "Already signed");
            c.partnerSigned = true;
        }
        
        emit SignedForRelease(_commitmentId, msg.sender);
        
        if (c.depositorSigned && c.partnerSigned) {
            c.released = true;
            emit FundsReleased(_commitmentId, c.depositor, c.amount);
            
            (bool success, ) = c.depositor.call{value: c.amount}("");
            require(success, "Transfer failed");
        }
    }
    
    /**
     * @notice Check time remaining (0 if expired)
     */
    function timeRemaining(uint256 _commitmentId) external view returns (uint256) {
        uint256 deadline = commitments[_commitmentId].deadline;
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
    
    /**
     * @notice Check if funds are permanently locked (deadline passed without release)
     */
    function isLocked(uint256 _commitmentId) external view returns (bool) {
        Commitment storage c = commitments[_commitmentId];
        return !c.released && block.timestamp >= c.deadline;
    }
}
