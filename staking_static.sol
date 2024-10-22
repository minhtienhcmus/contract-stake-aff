// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mintFromContract (address account, uint256 amount) external;
}
contract StaticStaking is Ownable(msg.sender) {
    IERC20 public stakeToken; // Token used for staking
    IERC20 public rewardToken; // Token used for rewards

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 typeStake;
        uint256 reward;
        bool withdrawn;
    }

    mapping(address => Stake[]) public stakes;

    uint256 public APR_3_MONTHS = 3000;  // 30% APR for 3 months
    uint256 public APR_6_MONTHS = 8000;  // 80% APR for 6 months.      dfddssfsgrfsfbddetdfdfddfdffsdfdsgrsddfdf.    dddde eeee e ee e ee e eeeee   
    uint256 public APR_12_MONTHS = 21900; // 219% APR for 12 months

    uint256 public constant SECONDS_IN_MONTH = 30 days;
    // uint256 public constant SECONDS_IN_MONTH = 1 minutes;
    uint256 public totalMustMintToClaim;
    uint256 public totalStaked;
    uint256 public numberTokenStopProgram = 5000000000000000000000000;
    event Staked(address indexed user, uint256 amount, uint256 months, uint256 reward);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    constructor(IERC20 _stakeToken, IERC20 _rewardToken) {
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
    }

    function stake(uint256 _amount, uint256 _months) external {
        require(totalMustMintToClaim < numberTokenStopProgram, "The amount of tokens minted as rewards exceeds the limit.");
        require(_amount > 0, "Amount must be greater than 0");
        require(_months == 3 || _months == 6 || _months == 12, "Invalid staking period");

        uint256 apr = _getAPR(_months);
        uint256 reward = (_amount * apr) / 10000; // Calculate reward based on APR
        uint256 endTime = block.timestamp + (_months * SECONDS_IN_MONTH);

        stakes[msg.sender].push(
            Stake({
                amount: _amount,
                startTime: block.timestamp,
                endTime: endTime,
                typeStake: _months,
                reward: reward,
                withdrawn: false
            })
        );

        stakeToken.transferFrom(msg.sender, address(this), _amount);
        totalMustMintToClaim += reward;
        totalStaked += _amount;
        emit Staked(msg.sender, _amount, _months, reward);
    }

    function withdraw(uint256 _stakeIndex) external {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        Stake storage userStake = stakes[msg.sender][_stakeIndex];

        require(!userStake.withdrawn, "Already withdrawn");
        require(block.timestamp >= userStake.endTime, "Stake is still locked");

        uint256 totalAmount = userStake.amount;
        uint256 rewardAmount = userStake.reward;

        userStake.withdrawn = true;

        // Transfer staked tokens and rewards
        stakeToken.transfer(msg.sender, totalAmount);

        rewardToken.mintFromContract(msg.sender, rewardAmount);
        totalStaked -= totalAmount;
        emit Withdrawn(msg.sender, totalAmount, rewardAmount);
    }

    function _getAPR(uint256 _months) internal returns (uint256) {
        if (_months == 3) return APR_3_MONTHS;
        if (_months == 6) return APR_6_MONTHS;
        if (_months == 12) return APR_12_MONTHS;
        return 0;
    }

    function getStakes(address _user) external view returns (Stake[] memory) {
        return stakes[_user];
    }

    function withdrawTokens(IERC20 token, uint256 _amount) external onlyOwner {
        token.transfer(owner(), _amount);
    }
    function setTokenReward(IERC20 _token) external onlyOwner {
        rewardToken = _token;
    }
    function setTokenstaking(IERC20 _token) external onlyOwner {
        stakeToken = _token;
    }
    function setAPR12(uint256 _value) external onlyOwner {
        APR_12_MONTHS = _value;
    }
    function setAPR6(uint256 _value) external onlyOwner {
        APR_6_MONTHS = _value;
    }
    function setAPR3(uint256 _value) external onlyOwner {
        APR_3_MONTHS = _value;
    }
    function setTokenStopProgram(uint256 _value) external onlyOwner {
        numberTokenStopProgram = _value;
    }
}
