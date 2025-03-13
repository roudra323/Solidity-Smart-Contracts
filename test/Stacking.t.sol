// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DeployStaking} from "script/DeployStaking.s.sol";
import {StakingHelperConfig} from "script/StakingHelperConfig.s.sol";
import {Staking} from "src/3_Staking.sol";

contract StakingTest is Test {
    address public stakingToken;
    address public rewardToken;
    uint256 public rewardRate;
    uint256 public defaultLockPeriod;
    uint256 public emergencyWithdrawalFee;
    uint256 public minimumStake;

    Staking public staking;

    // Dummy Users
    address USER1 = makeAddr("user1");
    address USER = makeAddr("user2");

    function setUp() external {
        DeployStaking deployStaking = new DeployStaking();
        (
            StakingHelperConfig.NetworkConfig memory config,
            Staking stakingInstance
        ) = deployStaking.run();

        staking = stakingInstance;

        stakingToken = config.stakingToken;
        rewardToken = config.rewardToken;
        rewardRate = config.rewardRate;
        defaultLockPeriod = config.defaultLockPeriod;
        minimumStake = config.minimumStake;
        emergencyWithdrawalFee = config.emergencyWithdrawFee;

        if (block.chainid == 31337) {}
    }

    function test_checkConfigs() external view {
        assertEq(staking.getStakingToken(), stakingToken);
        assertEq(staking.getRewardToken(), rewardToken);
        assertEq(staking.getRewardRate(), rewardRate);
        assertEq(staking.getDefaultLockPeriod(), defaultLockPeriod);
        assertEq(staking.getMinimumStake(), minimumStake);
        assertEq(staking.getEmergencyWithdrawalFee(), emergencyWithdrawalFee);
        assertEq(staking.getPrecision(), 1e18);
    }

    function test_CheckRewardMultiplier() external view {
        // 1 000 000 000 000 000 000
        console2.log(
            "Reward Multiplier ( basic tier ): ",
            staking.getRewardMultiplier(0)
        );

        // 1 250 000 000 000 000 000
        console2.log(
            "Reward Multiplier ( 1.25x silver ): ",
            staking.getRewardMultiplier(1)
        );

        // 1 500 000 000 000 000 000
        console2.log(
            "Reward Multiplier (1.5x gold ): ",
            staking.getRewardMultiplier(2)
        );

        assertEq(staking.getRewardMultiplier(0), 1e18);
        assertEq(staking.getRewardMultiplier(1), 1250000000000000000);
        assertEq(staking.getRewardMultiplier(2), 1500000000000000000);
    }
}
