// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mintFromContract (address account, uint256 amount) external;
}
contract TokenStaking is Ownable(msg.sender) {
    using SafeMath for uint256;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public apr; // Annual Percentage Rate (APR)
    uint256 public lastRewardBlock; // Last block number when rewards were distributed
    uint256 public totalStaked; // Total amount of tokens staked
    uint256 public accTokenPerShare; // Accumulated tokens per share, scaled up to prevent division precision loss

    uint256 public constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant BLOCKS_PER_YEAR = 10512000; // Roughly the number of blocks in a year on BSC

    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => Stake) public stakes;
    event stakePNCEvent(address add,  uint256 amount, uint256 timestamp);
    event unstakePNCEvent(address add,  uint256 amount, uint256 timestamp);
    event claimRewardPNCEvent(address add,  uint256 amount, uint256 timestamp);
    constructor(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _apr) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        apr = _apr;
        lastRewardBlock = block.number;
    }

    // Calculate tokens distributed per block based on APR
    function tokenPerBlock() public view returns (uint256) {
        if (totalStaked == 0) {
            return 0;
        }
        // Total rewards for 1 year = total staked * APR / 10000
        uint256 annualReward = totalStaked.mul(apr).div(10000);
        // Divide annual rewards by the total number of blocks in a year to get reward per block
        return annualReward.div(BLOCKS_PER_YEAR);
    }

    // Stake tokens
    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0 tokens");

        updatePool();

        Stake storage userStake = stakes[msg.sender];

        // If the user already has a stake, distribute any pending rewards
        if (userStake.amount > 0) {
            uint256 pendingReward = userStake.amount.mul(accTokenPerShare).div(1e12).sub(userStake.rewardDebt);
            if (pendingReward > 0) {
                rewardToken.mintFromContract(msg.sender, pendingReward);
            }
        }

        // Transfer staking tokens to the contract
        stakingToken.transferFrom(msg.sender, address(this), _amount);

        // Update user staking information
        userStake.amount = userStake.amount.add(_amount);
        userStake.rewardDebt = userStake.amount.mul(accTokenPerShare).div(1e12);

        totalStaked = totalStaked.add(_amount);
        emit stakePNCEvent(msg.sender, _amount, block.timestamp);
    }

    // Unstake tokens and claim rewards
    function unstake(uint256 _amount) external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= _amount, "Not enough staked tokens");

        updatePool();

        // Calculate pending rewards
        uint256 pendingReward = userStake.amount.mul(accTokenPerShare).div(1e12).sub(userStake.rewardDebt);
        
        // Transfer pending rewards to user
        if (pendingReward > 0) {
            rewardToken.mintFromContract(msg.sender, pendingReward);
        }
        
        // Transfer unstaked tokens back to the user
        stakingToken.transfer(msg.sender, _amount);

        // Update staking information
        userStake.amount = userStake.amount.sub(_amount);
        userStake.rewardDebt = userStake.amount.mul(accTokenPerShare).div(1e12);

        totalStaked = totalStaked.sub(_amount);
        emit unstakePNCEvent(msg.sender, _amount, block.timestamp);
    }

    // Claim pending rewards without unstaking
    function claimReward() external {
        Stake storage userStake = stakes[msg.sender];

        updatePool();

        // Calculate pending rewards
        uint256 pendingReward = userStake.amount.mul(accTokenPerShare).div(1e12).sub(userStake.rewardDebt);
        
        // Transfer pending rewards to user
        if (pendingReward > 0) {
            rewardToken.mintFromContract(msg.sender, pendingReward);
            userStake.rewardDebt = userStake.amount.mul(accTokenPerShare).div(1e12);
        }
        emit claimRewardPNCEvent(msg.sender,pendingReward, block.timestamp);
    }

    // Update the pool to distribute rewards since the last reward block
    function updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksSinceLastReward = block.number.sub(lastRewardBlock);
        uint256 reward = blocksSinceLastReward.mul(tokenPerBlock());

        // Accumulate tokens per staked share
        accTokenPerShare = accTokenPerShare.add(reward.mul(1e12).div(totalStaked));
        lastRewardBlock = block.number;
    }

    // View pending rewards for a user
    function pendingRewards(address _staker) external view returns (uint256) {
        Stake storage userStake = stakes[_staker];
        uint256 _accTokenPerShare = accTokenPerShare;

        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 blocksSinceLastReward = block.number.sub(lastRewardBlock);
            uint256 reward = blocksSinceLastReward.mul(tokenPerBlock());
            _accTokenPerShare = _accTokenPerShare.add(reward.mul(1e12).div(totalStaked));
        }

        return userStake.amount.mul(_accTokenPerShare).div(1e12).sub(userStake.rewardDebt);
    }

    // Set a new APR (owner only)
    function setAPR(uint256 _apr) external onlyOwner {
        updatePool();
        apr = _apr;
    }
    function setRewardToken(address _token) external onlyOwner {
        rewardToken  = IERC20(_token);
    }
    function setStakingToken(address _token) external onlyOwner {
        stakingToken  = IERC20(_token);
    }
    // Allow the contract owner to withdraw tokens in case of an emergency
    function withdrawTokens(uint256 _amount) external onlyOwner {
        rewardToken.transfer(msg.sender, _amount);
    }
}
