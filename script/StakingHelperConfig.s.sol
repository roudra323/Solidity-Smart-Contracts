// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Staking} from "src/3_Staking.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract StakingHelperConfig is Script {
    struct NetworkConfig {
        address stakingToken;
        address rewardToken;
        uint256 rewardRate;
        uint256 defaultLockPeriod;
    }

    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    // Local Chain Id / Mock Values
    uint256 public LOCAL_CHAIN_ID = 31337;
    uint256 public rewardRate = 5e16;
    uint256 public defaultLockPeriod = 30 days;

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
                rewardRate: rewardRate,
                defaultLockPeriod: defaultLockPeriod
            });
    }
}
