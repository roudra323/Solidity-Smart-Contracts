// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EnhancedStaking is ReentrancyGuard, Ownable, Pausable {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    // Precision for calculations (1e18)
    uint256 private constant PRECISION = 1e18;

    // Enhanced stake struct with more features
    struct Stake {
        uint128 amount; // Amount staked
        uint64 timestamp; // Time of stake
        uint64 lastClaim; // Last reward claim timestamp
        uint32 lockPeriod; // Custom lock period for this stake
        uint16 rewardTier; // Reward multiplier tier
    }

    // Stake info by user and stake ID
    mapping(address => mapping(uint256 => Stake)) public stakes;
    mapping(address => uint256) public stakeCount;

    // Configurable parameters
    uint256 public rewardRate;
    uint256 public minimumStake = 200e18; // Minimum stake
    uint256 public defaultLockPeriod;
    uint256 public totalStaked;

    // Reward tiers
    mapping(uint16 => uint256) public rewardMultipliers;

    // Emergency withdrawal fee
    uint256 public emergencyWithdrawalFee = 1e17; // 10%

    // Events
    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 lockPeriod
    );
    event Withdrawn(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount
    );
    event RewardClaimed(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount
    );
    event RewardRateUpdated(uint256 newRate);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 fee
    );

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _defaultLockPeriod
    ) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        defaultLockPeriod = _defaultLockPeriod;

        // Set up default reward tiers using precision
        rewardMultipliers[0] = PRECISION; // 1x for basic tier
        rewardMultipliers[1] = (PRECISION * 125) / 100; // 1.25x for silver tier
        rewardMultipliers[2] = (PRECISION * 150) / 100; // 1.5x for gold tier
    }

    // Stake tokens with optional custom lock period
    function stake(
        uint256 _amount,
        uint256 _lockPeriod
    ) external nonReentrant whenNotPaused {
        require(_amount >= minimumStake, "Below minimum stake");

        uint256 lockPeriod = _lockPeriod == 0 ? defaultLockPeriod : _lockPeriod;
        require(lockPeriod >= defaultLockPeriod, "Lock period too short");

        // @q is the amount in wei eg 200 or 200e18?
        // Calculate reward tier based on amount and lock period
        uint16 tier = calculateRewardTier(_amount, lockPeriod);

        // Transfer tokens to contract
        require(
            stakingToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        // Create new stake
        uint256 stakeId = stakeCount[msg.sender];
        Stake storage newStake = stakes[msg.sender][stakeId];
        newStake.amount = uint128(_amount);
        newStake.timestamp = uint64(block.timestamp);
        newStake.lastClaim = uint64(block.timestamp);
        newStake.lockPeriod = uint32(lockPeriod);
        newStake.rewardTier = tier;

        stakeCount[msg.sender]++;
        totalStaked += _amount;

        emit Staked(msg.sender, stakeId, _amount, lockPeriod);
    }

    // Calculate reward tier based on amount and lock period
    function calculateRewardTier(
        uint256 _amount,
        uint256 _lockPeriod
    ) public pure returns (uint16) {
        if (_amount >= 1000e18 && _lockPeriod >= 30 days) return 2; // Gold
        if (_amount >= 500e18 && _lockPeriod >= 14 days) return 1; // Silver
        return 0; // Basic
    }

    // Calculate pending rewards for a specific stake with proper precision
    function calculateRewards(
        address _user,
        uint256 _stakeId
    ) public view returns (uint256) {
        Stake memory userStake = stakes[_user][_stakeId];
        if (userStake.amount == 0) return 0;

        uint256 timeStaked = block.timestamp - userStake.lastClaim;

        // First multiply by large factors to maintain precision
        // Calculate base reward with precision
        uint256 baseReward = (userStake.amount * rewardRate * timeStaked) /
            (1 days * PRECISION); // rewardRate is now stored as `5e16` (5%) // Ensure we divide PRECISION properly

        // Apply tier multiplier (already stored as PRECISION-based value)
        uint256 finalReward = (baseReward *
            rewardMultipliers[userStake.rewardTier]) / PRECISION;

        return finalReward;
    }

    // Claim rewards for a specific stake
    function claimRewards(uint256 _stakeId) public nonReentrant whenNotPaused {
        uint256 rewards = calculateRewards(msg.sender, _stakeId);
        require(rewards > 0, "No rewards to claim");

        // Update last claim time
        stakes[msg.sender][_stakeId].lastClaim = uint64(block.timestamp);

        // Transfer rewards
        require(
            rewardToken.transfer(msg.sender, rewards),
            "Reward transfer failed"
        );

        emit RewardClaimed(msg.sender, _stakeId, rewards);
    }

    // Withdraw staked tokens
    // @q is reentrency can occur here for claiming rewards ?

    function withdraw(uint256 _stakeId) external nonReentrant whenNotPaused {
        Stake storage userStake = stakes[msg.sender][_stakeId];
        require(userStake.amount > 0, "No stake found");
        require(
            block.timestamp >= userStake.timestamp + userStake.lockPeriod,
            "Lock period not ended"
        );

        uint256 amount = userStake.amount;

        // Claim any pending rewards first
        if (calculateRewards(msg.sender, _stakeId) > 0) {
            claimRewards(_stakeId);
        }

        // Update total staked
        totalStaked -= amount;

        // Clear stake
        delete stakes[msg.sender][_stakeId];

        // Transfer tokens back to user
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");

        emit Withdrawn(msg.sender, _stakeId, amount);
    }

    // Emergency withdraw with penalty
    function emergencyWithdraw(uint256 _stakeId) external nonReentrant {
        Stake memory userStake = stakes[msg.sender][_stakeId];
        require(userStake.amount > 0, "No stake found");

        uint256 amount = userStake.amount;

        uint256 fee = (amount * emergencyWithdrawalFee) / PRECISION;

        // @q does all the amount withdrawed ?
        uint256 withdrawAmount = amount - fee;

        // Update total staked
        totalStaked = totalStaked - amount;

        // Clear stake
        delete stakes[msg.sender][_stakeId];

        // Transfer tokens back to user minus fee
        require(
            stakingToken.transfer(msg.sender, withdrawAmount),
            "Transfer failed"
        );

        emit EmergencyWithdraw(msg.sender, _stakeId, withdrawAmount, fee);
    }

    // Admin functions
    function setRewardRate(uint256 _newRate) external onlyOwner {
        rewardRate = _newRate;
        emit RewardRateUpdated(_newRate);
    }

    function setRewardMultiplier(
        uint16 _tier,
        uint256 _multiplier
    ) external onlyOwner {
        rewardMultipliers[_tier] = _multiplier;
    }

    function setEmergencyWithdrawalFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 2000, "Fee too high"); // Max 20%
        emergencyWithdrawalFee = _newFee;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency function to recover wrong tokens
    function recoverToken(address _token) external onlyOwner {
        require(
            _token != address(stakingToken),
            "Cannot recover staking token"
        );
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner(), balance), "Transfer failed");
    }
}
