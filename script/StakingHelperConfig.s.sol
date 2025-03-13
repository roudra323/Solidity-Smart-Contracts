// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Script} from "forge-std/Script.sol";
import {Staking} from "src/3_Staking.sol";

contract StakingHelperConfig is Script {
    struct NetworkConfig {
        address stakingToken;
        address rewardToken;
        uint256 rewardRate;
        uint256 defaultLockPeriod;
        uint256 minimumStake;
        uint256 emergencyWithdrawFee;
    }

    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;
    uint256 public rewardRate;
    uint256 public defaultLockPeriod;

    // Local Chain Id / Mock Values
    uint256 public LOCAL_CHAIN_ID = 31337;

    mapping(uint256 => NetworkConfig) public networkConfigs;

    function getConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigForChainId(block.chainid);
    }

    function getNetworkConfigForChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getLocalAnvilConfig();
        }
        return networkConfigs[chainId];
    }

    function getLocalAnvilConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[LOCAL_CHAIN_ID].stakingToken != address(0)) {
            return networkConfigs[LOCAL_CHAIN_ID];
        }

        vm.startBroadcast();
        stakingToken = new ERC20Mock();
        rewardToken = new ERC20Mock();
        vm.stopBroadcast();

        return
            NetworkConfig({
                stakingToken: address(stakingToken),
                rewardToken: address(rewardToken),
                rewardRate: 5e16, // 5%
                defaultLockPeriod: 30 days, // 30 days,
                minimumStake: 200e18,
                emergencyWithdrawFee: 1e17 // 10%
            });
    }
}
