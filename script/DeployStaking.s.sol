// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Staking} from "src/3_Staking.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployStaking is Script {
    ERC20 public stakingToken;
    ERC20 public rewardToken;
    uint256 public rewardRate;
    uint256 public defaultLockPeriod;

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
