// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {StakingHelperConfig} from "script/StakingHelperConfig.s.sol";
import {Staking} from "src/3_Staking.sol";

contract DeployStaking is Script {
    Staking public staking;

    function run()
        public
        returns (StakingHelperConfig.NetworkConfig memory, Staking)
    {
        StakingHelperConfig stackingHelperConfig = new StakingHelperConfig();
        StakingHelperConfig.NetworkConfig memory config = stackingHelperConfig
            .getConfig();

        vm.startBroadcast();
        staking = new Staking(
            config.stakingToken,
            config.rewardToken,
            config.rewardRate,
            config.defaultLockPeriod,
            config.minimumStake,
            config.emergencyWithdrawFee
        );
        vm.stopBroadcast();
        return (config, staking);
    }
}
