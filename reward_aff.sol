//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RewardAff {
    mapping(address => uint256) public rewardUser;  // Mapping to store user rewards
    address public owner; // Contract owner
    uint256 public threshold;
    constructor(uint256 _threshold) {
        owner = msg.sender;  // Set contract owner
        threshold = _threshold;
    }
    // function initialize(uint256 _threshold) public initializer {
    //     owner = msg.sender;
    //     threshold = _threshold;
    // }
    // Modifier to allow only the owner to perform certain actions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    // Modifier to check if the user has any reward to claim
    modifier hasReward() {
        require(rewardUser[msg.sender] > 0, "No rewards to claim");
        _;
    }

    // Function to add a reward to a single user's account (only owner can do this)
    function addReward(address _user, uint256 _amount) external onlyOwner {
        rewardUser[_user] += _amount;  // Add the reward to the user’s balance
    }

    // Function to add rewards for multiple users at once (only owner can do this)
    function addRewardForUsers(address[] memory _users, uint256[] memory _amounts) external onlyOwner {
        require(_users.length == _amounts.length, "Users and amounts length mismatch");
        for (uint256 i = 0; i < _users.length; i++) {
            rewardUser[_users[i]] += _amounts[i];  // Add the reward for each user
        }
    }

    // Function for users to claim their rewards
    function claimReward() external hasReward {
        uint256 rewardAmount = rewardUser[msg.sender];  // Get the user's reward amount
        rewardUser[msg.sender] = 0;  // Reset the reward to prevent reentrancy attacks

        // Ensure the contract has enough balance to transfer the reward
        require(address(this).balance >= rewardAmount, "Insufficient contract balance");
        require(rewardAmount >= threshold, "Amount reward withdraw must greater than threshold");
        
        // Transfer the reward (BNB) to the user
        (bool sent, ) = payable(msg.sender).call{value: rewardAmount}("");
        require(sent, "Failed to send BNB");
    }

    // Function to allow the owner to claim the remaining BNB in the contract
    function claimBNBToOwner() external onlyOwner {
        uint256 contractBalance = address(this).balance;  // Get the contract's BNB balance

        // Ensure there is balance in the contract to withdraw
        require(contractBalance > 0, "No BNB to claim");

        // Transfer the entire balance to the owner
        (bool sent, ) = payable(owner).call{value: contractBalance}("");
        require(sent, "Failed to send BNB to owner");
    }
    // Function to allow the owner to claim the remaining BNB in the contract
    function setThresholdWithdraw(uint _threshold) external onlyOwner {
        require(_threshold > 0, "Threshold must be greater than zero");
        threshold = _threshold;  // Get the contract's BNB balance
    }
    function setNewOwner(address _add) external onlyOwner {
        owner = _add;  // Get the contract's BNB balance
    }
        // Function to allow users to deposit ETH/BNB to the contract
    function depositETH() external payable {
        require(msg.value > 0, "Must send ETH to deposit");
        // You can optionally add logic to reward the sender with deposit bonuses
        // Example: rewardUser[msg.sender] += msg.value; (This is optional)
    }
    // Allow the contract to receive BNB
    receive() external payable {}

    // Fallback function
    fallback() external payable {}
}
